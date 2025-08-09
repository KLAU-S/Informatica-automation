#!/bin/bash

# manage_oracle_docker.sh - Enhanced script to manage Oracle XE Docker container
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/../docker-compose.yml"

# Source config if available
if [ -f "${SCRIPT_DIR}/00_config.sh" ]; then
    source "${SCRIPT_DIR}/00_config.sh"
    SCRIPT_NAME="manage_oracle_docker"
fi

function log_msg() {
    local message="$1"
    local level="${2:-INFO}"
    
    if command -v log_message &> /dev/null && [ -n "${SCRIPT_NAME:-}" ]; then
        log_message "$SCRIPT_NAME" "$message" "$level"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    fi
}

function show_usage() {
    echo "Usage: $0 [start|stop|status|logs|restart|clean|setup]"
    echo
    echo "Commands:"
    echo "  start   - Start the Oracle XE container"
    echo "  stop    - Stop the Oracle XE container"
    echo "  status  - Show container status"
    echo "  logs    - Show container logs"
    echo "  restart - Restart the container"
    echo "  clean   - Stop container and remove volumes"
    echo "  setup   - Setup database users after container start"
}

function check_docker() {
    if ! command -v docker &> /dev/null; then
        log_msg "Docker is not installed or not in PATH" "ERROR"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_msg "Docker Compose is not available" "ERROR"
        exit 1
    fi
}

function wait_for_oracle() {
    log_msg "Waiting for Oracle to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" exec -T oracle-xe sqlplus -L "system/oracle@//localhost:1521/XE" <<< "SELECT 1 FROM dual;" &>/dev/null; then
            log_msg "Oracle is ready after $attempt attempts!"
            return 0
        fi
        
        if [ $((attempt % 5)) -eq 0 ]; then
            log_msg "Still waiting... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_msg "Timeout waiting for Oracle to be ready after $max_attempts attempts" "ERROR"
    return 1
}

function setup_oracle_users() {
    log_msg "Setting up Oracle database users..."
    
    # Create SQL script content for user setup
    local sql_content='-- Connect as SYSTEM to create users
CONNECT system/oracle@XE;

-- Drop existing users if they exist (ignore errors)
BEGIN
   EXECUTE IMMEDIATE '\''DROP USER INFA_DOM CASCADE'\'';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

BEGIN
   EXECUTE IMMEDIATE '\''DROP USER INFA_REP CASCADE'\'';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- Create INFA_DOM user
CREATE USER INFA_DOM IDENTIFIED BY INFA_DOM
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;

GRANT CONNECT, RESOURCE, DBA TO INFA_DOM;
GRANT UNLIMITED TABLESPACE TO INFA_DOM;

-- Create INFA_REP user  
CREATE USER INFA_REP IDENTIFIED BY INFA_REP
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;

GRANT CONNECT, RESOURCE, DBA TO INFA_REP;
GRANT UNLIMITED TABLESPACE TO INFA_REP;

-- Unlock and setup HR user
ALTER USER HR IDENTIFIED BY HR ACCOUNT UNLOCK;
GRANT CONNECT, RESOURCE TO HR;

-- Set OPEN_CURSORS parameter
ALTER SYSTEM SET open_cursors = 1000 SCOPE = BOTH;

-- Verify users
PROMPT === User Status ===
SELECT username, account_status FROM dba_users WHERE username IN ('\''INFA_DOM'\'', '\''INFA_REP'\'', '\''HR'\'');

-- Show open_cursors setting
PROMPT === Open Cursors Setting ===
SELECT name, value FROM v$parameter WHERE name = '\''open_cursors'\'';

PROMPT === Setup Complete ===
EXIT;'

    # Create temporary SQL file on host
    local sql_script="/tmp/setup_infa_users_$$.sql"
    echo "$sql_content" > "$sql_script"
    
    # Copy the SQL script to the container
    if docker cp "$sql_script" "${ORACLE_CONTAINER_NAME}:/tmp/setup_infa_users.sql"; then
        log_msg "SQL script copied to container successfully"
    else
        log_msg "Failed to copy SQL script to container" "ERROR"
        rm -f "$sql_script"
        return 1
    fi
    
    # Execute the SQL script in the container
    if docker compose -f "$COMPOSE_FILE" exec -T oracle-xe sqlplus /nolog < "$sql_script"; then
        log_msg "Oracle users setup completed successfully"
    else
        log_msg "Failed to setup Oracle users" "ERROR"
        rm -f "$sql_script"
        return 1
    fi
    
    # Clean up temporary files
    rm -f "$sql_script"
    docker compose -f "$COMPOSE_FILE" exec -T oracle-xe rm -f /tmp/setup_infa_users.sql
}

function test_connections() {
    log_msg "Testing database connections..."
    
    local users=("system/oracle" "INFA_DOM/INFA_DOM" "INFA_REP/INFA_REP" "HR/HR")
    
    for user in "${users[@]}"; do
        if docker compose -f "$COMPOSE_FILE" exec -T oracle-xe sqlplus -L "${user}@//localhost:1521/XE" <<< "SELECT 'Connection successful for '||USER FROM dual;" &>/dev/null; then
            log_msg "✓ Connection test successful for: ${user%%/*}"
        else
            log_msg "✗ Connection test failed for: ${user%%/*}" "WARN"
        fi
    done
}

function show_oracle_info() {
    log_msg "Oracle XE Connection Information:"
    echo "=================================="
    echo "Host: localhost"
    echo "Port: 1521"
    echo "SID: XE"
    echo "Service Name: XE"
    echo ""
    echo "Users created:"
    echo "- SYSTEM/oracle (admin)"
    echo "- INFA_DOM/INFA_DOM (domain user)"
    echo "- INFA_REP/INFA_REP (repository user)"
    echo "- HR/HR (sample user)"
    echo ""
    echo "Connection strings:"
    echo "- system/oracle@//localhost:1521/XE"
    echo "- INFA_DOM/INFA_DOM@//localhost:1521/XE"
    echo "- INFA_REP/INFA_REP@//localhost:1521/XE"
    echo "- HR/HR@//localhost:1521/XE"
    echo "=================================="
}

# Check prerequisites
check_docker

case "$1" in
    start)
        log_msg "Starting Oracle XE container..."
        docker compose -f "$COMPOSE_FILE" up -d
        if wait_for_oracle; then
            setup_oracle_users
            test_connections
            show_oracle_info
            log_msg "Oracle XE container started and configured successfully"
        else
            log_msg "Oracle container started but failed to become ready" "ERROR"
            exit 1
        fi
        ;;
    stop)
        log_msg "Stopping Oracle XE container..."
        docker compose -f "$COMPOSE_FILE" stop
        log_msg "Oracle XE container stopped"
        ;;
    status)
        echo "=== Container Status ==="
        docker compose -f "$COMPOSE_FILE" ps
        echo
        echo "=== Container Health ==="
        docker inspect oracle-xe --format='{{.State.Health.Status}}' 2>/dev/null || echo "Health check not available"
        echo
        if docker compose -f "$COMPOSE_FILE" ps | grep -q "oracle-xe.*Up"; then
            show_oracle_info
        fi
        ;;
    logs)
        docker compose -f "$COMPOSE_FILE" logs -f
        ;;
    restart)
        log_msg "Restarting Oracle XE container..."
        docker compose -f "$COMPOSE_FILE" restart
        if wait_for_oracle; then
            test_connections
            show_oracle_info
            log_msg "Oracle XE container restarted successfully"
        else
            log_msg "Oracle container restarted but failed to become ready" "ERROR"
            exit 1
        fi
        ;;
    clean)
        log_msg "Stopping container and removing volumes..."
        docker compose -f "$COMPOSE_FILE" down -v
        log_msg "Oracle XE container and volumes removed"
        ;;
    setup)
        if docker compose -f "$COMPOSE_FILE" ps | grep -q "oracle-xe.*Up"; then
            setup_oracle_users
            test_connections
            show_oracle_info
        else
            log_msg "Oracle container is not running. Start it first with: $0 start" "ERROR"
            exit 1
        fi
        ;;
    *)
        show_usage
        exit 1
        ;;
esac