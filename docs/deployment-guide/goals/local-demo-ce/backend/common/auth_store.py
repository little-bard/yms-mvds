import os
import json
import hashlib
from pathlib import Path

# Configuration constants
JWT_SECRET_KEY = "SUPER_SECRET_JWT_KEY"  # You can change this in environment variables
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 86400  # 60 days

# File paths for storage
AUTH_DIR = Path("./data/auth")
USER_DB_FILE = AUTH_DIR / "users.json"
TOKEN_DB_FILE = AUTH_DIR / "tokens.json"

# Ensure directory exists
AUTH_DIR.mkdir(parents=True, exist_ok=True)

def hash_password(password: str) -> str:
    """Create a simple hash for password"""
    return hashlib.sha256(password.encode()).hexdigest()

def _load_users_db():
    """Load users from file or return empty dict if file doesn't exist"""
    if not USER_DB_FILE.exists():
        return {}
    
    try:
        with open(USER_DB_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return {}

def _save_users_db(users):
    """Save users to file"""
    with open(USER_DB_FILE, 'w') as f:
        json.dump(users, f, indent=2)

def _load_tokens_db():
    """Load tokens from file or return empty dict if file doesn't exist"""
    if not TOKEN_DB_FILE.exists():
        return {}
    
    try:
        with open(TOKEN_DB_FILE, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return {}

def _save_tokens_db(tokens):
    """Save tokens to file"""
    with open(TOKEN_DB_FILE, 'w') as f:
        json.dump(tokens, f, indent=2)

# Initialize with default user if none exists
def init_default_user(username="admin", password="admin"):
    """Initialize database with a default user if empty"""
    users = _load_users_db()
    if not users:
        users[username] = hash_password(password)
        _save_users_db(users)
        return True
    return False

# User operations
def add_user(username, password):
    """Add or update a user in the database"""
    users = _load_users_db()
    users[username] = hash_password(password)
    _save_users_db(users)
    return True

def verify_user(username, password):
    """Verify a user's credentials"""
    users = _load_users_db()
    stored_hash = users.get(username)
    
    if not stored_hash:
        return False
    
    return stored_hash == hash_password(password)

def get_user(username):
    """Get a user if it exists"""
    users = _load_users_db()
    return username in users

def delete_user(username):
    """Delete a user from the database"""
    users = _load_users_db()
    if username not in users:
        return False
    
    del users[username]
    _save_users_db(users)
    return True

# Token operations
def save_token(username, token, expires_at):
    """Save token to persistent storage"""
    tokens = _load_tokens_db()
    tokens[token] = {
        "username": username,
        "expires_at": expires_at
    }
    _save_tokens_db(tokens)

def validate_token(token):
    """Validate a token and return username if valid"""
    tokens = _load_tokens_db()
    token_data = tokens.get(token)
    
    if not token_data:
        return None
    
    import datetime
    if datetime.datetime.utcnow().timestamp() > token_data["expires_at"]:
        # Token expired, remove it
        del tokens[token]
        _save_tokens_db(tokens)
        return None
    
    return token_data["username"]

def delete_token(token):
    """Delete a token from the database"""
    tokens = _load_tokens_db()
    if token not in tokens:
        return False
    
    del tokens[token]
    _save_tokens_db(tokens)
    return True

# Initialize with default user when module is loaded
init_default_user(username="admin", password="administrator")