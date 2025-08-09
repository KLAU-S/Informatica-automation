# FILE: main_setup.sh (Fixed with single log file)
#!/bin/bash

# main_setup.sh - Fixed main orchestrator for Informatica PowerCenter installation

# Strict mode
set -o errexit
set -o nounset
set -o pipefail

# --- Load Configuration and Initialize Single Log File ---
CONFIG_FILE_PATH="$(dirname "$0")/00_config.sh"
if [ ! -f "$CONFIG_FILE_PATH" ]; then
    echo "CRITICAL: Configuration file not found at $CONFIG_FILE_PATH" >&2
    exit 1
fi

source "$CONFIG_FILE_PATH"
init_logging "$MAIN_LOG_FILE"
SCRIPT_NAME="main_setup"

# --- Pre-flight Checks ---
log_message "$SCRIPT_NAME" "Starting Informatica PowerCenter installation process..." "INFO"
log_message "$SCRIPT_NAME" "Log file: $MAIN_LOG_FILE" "INFO"

if [ "$(id -u)" -eq 0 ]; then
    log_message "$SCRIPT_NAME" "This script should not be run as root. Run as a user with sudo privileges." "ERROR"
    exit 1
fi

if ! command -v sudo &> /dev/null; then
    log_message "$SCRIPT_NAME" "sudo command not found. Please install sudo." "ERROR"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    log_message "$SCRIPT_NAME" "Docker not found. Please install Docker and Docker Compose." "ERROR"
    exit 1
fi

# Create base directories
mkdir -p "${DOWNLOAD_DIR}/informatica" "${DOWNLOAD_DIR}/jdk" "${DOWNLOAD_DIR}/oracle" "${DOWNLOAD_DIR}/sqldeveloper"
mkdir -p "$TEMP_INSTALL_DIR" "$LOG_DIR" "$INFA_RESPONSE_FILES_DIR"
log_message "$SCRIPT_NAME" "Base directories created." "INFO"

# --- Installation Steps ---
STEPS=(
    "01_download_prerequisites.sh"
    "02_install_jdk.sh"
    "03_start_oracle_docker.sh"
    "04_install_sqldeveloper.sh"
    "05_configure_sqldeveloper.sh"
    "06_prepare_informatica_installers.sh"
    "07_install_informatica_server.sh"
    # "08_configure_informatica_services.sh"
)

for step_script in "${STEPS[@]}"; do
    log_message "$SCRIPT_NAME" "=== Executing step: ${step_script} ===" "INFO"
    
    STEP_SCRIPT_PATH="${SCRIPTS_DIR}/${step_script}"
    if [ ! -f "$STEP_SCRIPT_PATH" ]; then
        log_message "$SCRIPT_NAME" "Step script not found: $STEP_SCRIPT_PATH" "ERROR"
        exit 1
    fi
    
    # Execute step script with unified logging
    if ! bash "$STEP_SCRIPT_PATH"; then
        log_message "$SCRIPT_NAME" "Step ${step_script} failed. Aborting installation." "ERROR"
        echo "ERROR: Step ${step_script} failed. Check ${MAIN_LOG_FILE} for details." >&2
        exit 1
    fi
    
    log_message "$SCRIPT_NAME" "=== Step ${step_script} completed successfully ===" "INFO"
done

log_message "$SCRIPT_NAME" "Informatica PowerCenter installation process completed." "INFO"
log_message "$SCRIPT_NAME" "Please check the main log file for details: ${MAIN_LOG_FILE}" "INFO"
log_message "$SCRIPT_NAME" "Remember to source relevant profile scripts (e.g., /etc/profile.d/jdk.sh, oracle_xe.sh, informatica.sh) or reboot for changes to take effect system-wide." "INFO"

exit 0
