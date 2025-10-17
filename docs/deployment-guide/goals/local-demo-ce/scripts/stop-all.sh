#!/bin/bash

# EDC 환경 전체 중지 스크립트
# EDC Environment Stop All Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🛑 EDC 환경 전체 중지 중..."
echo "========================="

cd "$PROJECT_DIR"

STOP_COUNT=0

# 개발 환경 중지
echo ""
echo "🔧 개발 환경 중지 중..."
if [[ -f ".env.dev" ]] && [[ -f "docker-compose.dev.yaml" ]]; then
    if docker compose -f docker-compose.dev.yaml --env-file .env.dev ps --quiet 2>/dev/null | grep -q .; then
        echo "🛑 개발 환경 컨테이너 중지 중..."
        docker compose -f docker-compose.dev.yaml --env-file .env.dev down --timeout 30
        echo "✅ 개발 환경 중지 완료"
        ((STOP_COUNT++))
    else
        echo "ℹ️  개발 환경이 실행되지 않음"
    fi
else
    echo "⚠️  개발 환경 설정 파일 없음"
fi

# 프로덕션 환경 중지
echo ""
echo "🏭 프로덕션 환경 중지 중..."
if [[ -f ".env.prod" ]] && [[ -f "docker-compose.prod.yaml" ]]; then
    if docker compose -f docker-compose.prod.yaml --env-file .env.prod ps --quiet 2>/dev/null | grep -q .; then
        echo "🛑 프로덕션 환경 컨테이너 중지 중..."
        docker compose -f docker-compose.prod.yaml --env-file .env.prod down --timeout 30
        echo "✅ 프로덕션 환경 중지 완료"
        ((STOP_COUNT++))
    else
        echo "ℹ️  프로덕션 환경이 실행되지 않음"
    fi
else
    echo "⚠️  프로덕션 환경 설정 파일 없음"
fi

# 고아 컨테이너 정리
echo ""
echo "🧹 고아 컨테이너 정리 중..."
ORPHAN_CONTAINERS=$(docker ps -a --filter "name=edc-" --filter "status=exited" --quiet)
if [[ -n "$ORPHAN_CONTAINERS" ]]; then
    echo "🗑️  종료된 EDC 컨테이너 제거 중..."
    docker rm $ORPHAN_CONTAINERS
    echo "✅ 고아 컨테이너 정리 완료"
else
    echo "ℹ️  정리할 고아 컨테이너 없음"
fi

# 미사용 네트워크 정리
echo ""
echo "🌐 미사용 네트워크 정리 중..."
UNUSED_NETWORKS=$(docker network ls --filter "name=edc-" --quiet)
if [[ -n "$UNUSED_NETWORKS" ]]; then
    for network in $UNUSED_NETWORKS; do
        NETWORK_NAME=$(docker network inspect $network --format '{{.Name}}' 2>/dev/null)
        NETWORK_CONTAINERS=$(docker network inspect $network --format '{{len .Containers}}' 2>/dev/null)
        if [[ "$NETWORK_CONTAINERS" == "0" ]]; then
            echo "🗑️  미사용 네트워크 제거: $NETWORK_NAME"
            docker network rm $network 2>/dev/null || true
        fi
    done
else
    echo "ℹ️  정리할 네트워크 없음"
fi

# 포트 사용 확인
echo ""
echo "🔍 포트 해제 확인..."
EDC_PORTS=(30000 30100 30200 30300 30001 30002 30101 30102 30201 30202 30301 30302 30010 30110 30210 30310 8080 8443)
STILL_USED=()

for port in "${EDC_PORTS[@]}"; do
    if ss -tuln | grep -q ":$port "; then
        STILL_USED+=($port)
    fi
done

if [[ ${#STILL_USED[@]} -gt 0 ]]; then
    echo "⚠️  다음 포트들이 여전히 사용 중입니다: ${STILL_USED[*]}"
    echo "   다른 프로세스가 사용 중일 수 있습니다."
    echo ""
    echo "포트 사용 프로세스 확인:"
    for port in "${STILL_USED[@]}"; do
        PROCESS=$(ss -tulnp | grep ":$port " | head -n 1)
        echo "   Port $port: $PROCESS"
    done
else
    echo "✅ 모든 EDC 포트가 해제됨"
fi

# 결과 요약
echo ""
echo "========================="
echo "🎉 중지 작업 완료!"
echo "========================="
echo ""

if [[ $STOP_COUNT -gt 0 ]]; then
    echo "✅ $STOP_COUNT개 환경 중지됨"
else
    echo "ℹ️  중지할 환경이 없었음"
fi

echo ""
echo "💾 추가 정리 옵션:"
echo "   Docker 이미지 정리:  docker image prune -f"
echo "   볼륨 정리:          docker volume prune -f"
echo "   전체 시스템 정리:    docker system prune -a -f"
echo ""
echo "🚀 환경 재시작:"
echo "   개발 환경:          ./scripts/start-dev.sh"
echo "   프로덕션 환경:       ./scripts/start-prod.sh"
echo "   상태 확인:          ./scripts/status.sh"
echo ""