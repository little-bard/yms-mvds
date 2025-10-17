#!/bin/bash

# EDC 개발 환경 시작 스크립트
# EDC Development Environment Startup Script

docker compose -p edc-dev -f ../docker-compose.dev.yaml --env-file ../.env.dev up -d