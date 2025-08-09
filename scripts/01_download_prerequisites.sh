#!/bin/bash

# 01_download_prerequisites.sh
# Downloads JDK and Oracle XE if not already present.

source "$(dirname "$0")/00_config.sh"
# *** ADDED/CORRECTED LINE BELOW ***
SCRIPT_NAME="01_download_prerequisites"

log_message "$SCRIPT_NAME" "Starting prerequisite download process." "INFO"

# Function to download a file if it doesn't exist
download_file() {
    local url="$1"
    local destination_path="$2"
    local file_name
    file_name=$(basename "$destination_path")

    if [ -f "$destination_path" ]; then
        log_message "$SCRIPT_NAME" "File ${file_name} already exists at ${destination_path}. Skipping download." "INFO"
    else
        log_message "$SCRIPT_NAME" "Downloading ${file_name} from ${url} to ${destination_path}..." "INFO"
        if ! exec_cmd "$SCRIPT_NAME" "wget --progress=bar:force -O \"${destination_path}\" \"${url}\"" \
            "Successfully downloaded ${file_name}." \
            "Failed to download ${file_name}."; then
            return 1
        fi
    fi
    return 0
}

# Download JDK
if ! download_file "${JDK_DOWNLOAD_URL}" "${DOWNLOAD_DIR}/jdk/${JDK_ARCHIVE_NAME}"; then
    log_message "$SCRIPT_NAME" "Exiting due to JDK download failure." "ERROR" # Added more specific exit log
    exit 1
fi

# # Download Oracle XE RPM Zip
# if ! download_file "${ORACLE_DOWNLOAD_URL}" "${DOWNLOAD_DIR}/oracle/${ORACLE_RPM_ZIP_NAME}"; then
#     log_message "$SCRIPT_NAME" "Exiting due to Oracle XE download failure." "ERROR" # Added more specific exit log
#     exit 1
# fi

log_message "$SCRIPT_NAME" "Please ensure Informatica V4* ZIP files are in ${DOWNLOAD_DIR}/informatica/" "INFO"
log_message "$SCRIPT_NAME" "The script will attempt to find ${INFA_LICENSE_KEY_NAME} within these zips or in ${DOWNLOAD_DIR}/informatica/ directly." "INFO"
log_message "$SCRIPT_NAME" "Please ensure ${SQLDEV_RPM_NAME} is in ${DOWNLOAD_DIR}/sqldeveloper/" "INFO"

log_message "$SCRIPT_NAME" "Prerequisite download checks completed." "INFO"
exit 0