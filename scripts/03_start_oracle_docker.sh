#!/bin/bash
source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="03_start_oracle_docker"

log_message "$SCRIPT_NAME" "Attempting to start Oracle XE Docker container..." "INFO"

CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute manage_oracle_docker.sh and let its output go to stdout/stderr.
# These will be captured by the overall main_setup.sh logging if it redirects.
# The log_message calls within this script will go to $MAIN_LOG_FILE.

log_message "$SCRIPT_NAME" "Executing: ${CURRENT_SCRIPT_DIR}/manage_oracle_docker.sh start" "DEBUG"

# Call manage_oracle_docker.sh. Its echo statements will go to stdout.
# The log_message calls in this script go to $MAIN_LOG_FILE.
if ! "${CURRENT_SCRIPT_DIR}/manage_oracle_docker.sh" start; then
    log_message "$SCRIPT_NAME" "Failed to start Oracle XE Docker container (as reported by manage_oracle_docker.sh)." "ERROR"
    exit 1
fi

log_message "$SCRIPT_NAME" "Oracle XE Docker container command executed successfully (manage_oracle_docker.sh reported success)." "INFO"
exit 0 