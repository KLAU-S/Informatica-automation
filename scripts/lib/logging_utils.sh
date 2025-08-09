#!/bin/bash

# logging_utils.sh - Centralized logging utilities

# Initialize logging - create log file and set up logging
init_logging() {
    local log_file="$1"
    local log_dir
    log_dir=$(dirname "$log_file")
    
    # Create log directory if it doesn't exist
    mkdir -p "$log_dir"
    
    # Create/truncate the log file for this run
    : > "$log_file"
    
    # Set global log file variable
    export LOG_FILE="$log_file"
    
    # Log the start of this session
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SYSTEM] [INFO] Logging initialized: $log_file" >> "$log_file"
}

# Log a message with timestamp, script name, and level
log_message() {
    local script_name="$1"
    local message="$2"
    local level="${3:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$script_name] [$level] $message" >> "$LOG_FILE"
    
    # Also echo to stdout for real-time feedback
    case "$level" in
        ERROR)
            echo "ERROR [$script_name]: $message" >&2
            ;;
        WARN)
            echo "WARN [$script_name]: $message"
            ;;
        INFO|DEBUG)
            echo "[$script_name]: $message"
            ;;
    esac
}

# Execute a command with logging
exec_cmd() {
    local script_name="$1"
    local command="$2"
    local success_msg="$3"
    local error_msg="$4"
    
    log_message "$script_name" "Executing: $command" "DEBUG"
    
    if eval "$command" >> "$LOG_FILE" 2>&1; then
        if [ -n "$success_msg" ]; then
            log_message "$script_name" "$success_msg" "INFO"
        fi
        return 0
    else
        if [ -n "$error_msg" ]; then
            log_message "$script_name" "$error_msg" "ERROR"
        fi
        return 1
    fi
}