#!/bin/bash

# 06_prepare_informatica_installers.sh
# Extracts the main Informatica V4* ZIP files and then the actual server installer archive.
# Places the license key in the expected location.

source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="06_prepare_infa_install"

# Ensure logging is initialized when running this script directly (outside main_setup)
if [ -z "${LOG_FILE:-}" ] || [ ! -f "${LOG_FILE:-/dev/null}" ]; then
    init_logging "$MAIN_LOG_FILE"
fi

log_message "$SCRIPT_NAME" "Starting Informatica installer preparation." "INFO"

INFA_DOWNLOAD_DIR="${DOWNLOAD_DIR}/informatica"
MAIN_ZIPS_STAGING_DIR="${TEMP_INSTALL_DIR}/informatica_extracted_main_zips"
SERVER_INSTALLER_PAYLOAD_DIR="${TEMP_INSTALL_DIR}/informatica_server_installer_payload" # This is where install.sh should end up

# Use a local (non-HGFS) workspace for heavy extraction to avoid I/O issues on shared folders
LOCAL_WORK_BASE="/var/tmp/infa_prepare"
LOCAL_DAC_PARTS_DIR="${LOCAL_WORK_BASE}/dac_parts"
LOCAL_DAC_EXTRACT_DIR="${LOCAL_WORK_BASE}/dac_extracted"

# Ensure required CLI tools are available (unzip/7z) for robust extraction
ensure_extraction_tools() {
    local need_unzip=false
    local need_7z=false

    if ! command -v unzip >/dev/null 2>&1; then
        need_unzip=true
    fi
    if ! command -v 7z >/dev/null 2>&1; then
        need_7z=true
    fi

    if $need_unzip || $need_7z; then
        if command -v yum >/dev/null 2>&1; then
            log_message "$SCRIPT_NAME" "Installing missing extraction tools (unzip/p7zip) via yum..." "INFO"
            sudo yum install -y unzip p7zip p7zip-plugins >> "$LOG_FILE" 2>&1 || true
        elif command -v dnf >/dev/null 2>&1; then
            log_message "$SCRIPT_NAME" "Installing missing extraction tools (unzip/p7zip) via dnf..." "INFO"
            sudo dnf install -y unzip p7zip p7zip-plugins >> "$LOG_FILE" 2>&1 || true
        fi
    fi

    # Re-check and error if still missing critical tool 7z (needed for split ZIP)
    if ! command -v 7z >/dev/null 2>&1; then
        log_message "$SCRIPT_NAME" "7z is required for extracting multi-part archives but is not available. Please install p7zip." "ERROR"
        exit 1
    fi
}

ensure_extraction_tools

# Idempotency check: if server payload dir has install.sh, and license key is ready, skip.
if [ -f "${SERVER_INSTALLER_PAYLOAD_DIR}/install.sh" ] && [ -f "${INFA_DOWNLOAD_DIR}/${INFA_LICENSE_KEY_NAME}" ]; then
    log_message "$SCRIPT_NAME" "Informatica server installer payload (install.sh) and license key seem to be already prepared. Skipping." "INFO"
    exit 0
elif [ -f "${SERVER_INSTALLER_PAYLOAD_DIR}/install.sh" ]; then
    log_message "$SCRIPT_NAME" "Installer payload exists, but license key missing. Will try to locate license key." "WARN"
    # Proceed to license key check/copy
elif [ -d "$SERVER_INSTALLER_PAYLOAD_DIR" ] && [ "$(ls -A $SERVER_INSTALLER_PAYLOAD_DIR)" ]; then
     log_message "$SCRIPT_NAME" "Server installer payload directory ${SERVER_INSTALLER_PAYLOAD_DIR} exists but seems incomplete (no install.sh). Cleaning and re-preparing." "WARN"
     sudo rm -rf "${SERVER_INSTALLER_PAYLOAD_DIR:?}"/* # Protect against empty var
else
    log_message "$SCRIPT_NAME" "Server installer payload directory does not exist or is empty. Full preparation needed." "INFO"
fi


# Only extract main zips if staging dir lacks expected artifacts
NEEDS_MAIN_ZIP_EXTRACTION=true

# Helper: check if DAC parts exist in staging
staging_has_dac_parts() {
    local base="${MAIN_ZIPS_STAGING_DIR}/dac_win_11g_infa_linux_64bit_951"
    [ -f "${base}.zip" ] && [ -f "${base}.z01" ] && [ -f "${base}.z02" ] && [ -f "${base}.z03" ]
}

if [ -d "$MAIN_ZIPS_STAGING_DIR" ] && [ "$(ls -A "$MAIN_ZIPS_STAGING_DIR")" ]; then
    if find "${MAIN_ZIPS_STAGING_DIR}" -maxdepth 1 -name "${INFA_SERVER_INSTALLER_ARCHIVE}" -print -quit 2>/dev/null | grep -q .; then
        log_message "$SCRIPT_NAME" "Found server installer archive '${INFA_SERVER_INSTALLER_ARCHIVE}' in staging ${MAIN_ZIPS_STAGING_DIR}. Skipping main ZIP extraction." "INFO"
        NEEDS_MAIN_ZIP_EXTRACTION=false
    elif staging_has_dac_parts; then
        log_message "$SCRIPT_NAME" "DAC split ZIP parts already present in staging ${MAIN_ZIPS_STAGING_DIR}. Skipping main ZIP extraction." "INFO"
        NEEDS_MAIN_ZIP_EXTRACTION=false
    else
        log_message "$SCRIPT_NAME" "Staging ${MAIN_ZIPS_STAGING_DIR} exists but expected artifacts missing. Will extract main ZIPs without cleaning existing files." "WARN"
    fi
else
    mkdir -p "$MAIN_ZIPS_STAGING_DIR"
fi

if $NEEDS_MAIN_ZIP_EXTRACTION; then
    log_message "$SCRIPT_NAME" "Looking for Informatica main ZIP files (V*.zip) in ${INFA_DOWNLOAD_DIR}." "INFO"
    main_zip_files=($(find "${INFA_DOWNLOAD_DIR}" -maxdepth 1 -name "V*.zip" -print))

    if [ ${#main_zip_files[@]} -eq 0 ]; then
        log_message "$SCRIPT_NAME" "No Informatica main ZIP files (e.g., V41976-01_1of4.zip) found in ${INFA_DOWNLOAD_DIR}." "ERROR"
        exit 1
    fi

    log_message "$SCRIPT_NAME" "Found ${#main_zip_files[@]} main ZIP files. Extracting missing contents to ${MAIN_ZIPS_STAGING_DIR}..." "INFO"
    for zip_file in "${main_zip_files[@]}"; do
        # Idempotent: if this zip's expected outputs seem present, skip extracting this zip
        case "$(basename "$zip_file")" in
            V*_1of4.zip)
                if [ -f "${MAIN_ZIPS_STAGING_DIR}/dac_win_11g_infa_linux_64bit_951.zip" ]; then
                    log_message "$SCRIPT_NAME" "Skip: contents of ${zip_file} already present." "INFO"
                    continue
                fi
                ;;
            V*_2of4.zip)
                if [ -f "${MAIN_ZIPS_STAGING_DIR}/dac_win_11g_infa_linux_64bit_951.z01" ]; then
                    log_message "$SCRIPT_NAME" "Skip: contents of ${zip_file} already present." "INFO"
                    continue
                fi
                ;;
            V*_3of4.zip)
                if [ -f "${MAIN_ZIPS_STAGING_DIR}/dac_win_11g_infa_linux_64bit_951.z02" ]; then
                    log_message "$SCRIPT_NAME" "Skip: contents of ${zip_file} already present." "INFO"
                    continue
                fi
                ;;
            V*_4of4.zip)
                if [ -f "${MAIN_ZIPS_STAGING_DIR}/dac_win_11g_infa_linux_64bit_951.z03" ] || [ -f "${MAIN_ZIPS_STAGING_DIR}/${INFA_SERVER_INSTALLER_ARCHIVE}" ]; then
                    log_message "$SCRIPT_NAME" "Skip: contents of ${zip_file} already present." "INFO"
                    continue
                fi
                ;;
        esac
        log_message "$SCRIPT_NAME" "Extracting ${zip_file}..." "INFO"
        if ! exec_cmd "$SCRIPT_NAME" "unzip -o \"${zip_file}\" -d \"${MAIN_ZIPS_STAGING_DIR}\"" \
            "Successfully extracted ${zip_file}." \
            "Failed to extract ${zip_file}."; then
            exit 1
        fi
    done
    log_message "$SCRIPT_NAME" "Main ZIP extraction stage completed." "INFO"
fi

# --- New step: Extract the multi-part DAC archive (locally, not on HGFS) ---
DAC_ARCHIVE_EXTRACTED_CONTENTS_DIR="${MAIN_ZIPS_STAGING_DIR}/dac_extracted_contents" # kept as a logical marker only

# Determine whether we need to extract DAC parts to discover contents
NEEDS_DAC_EXTRACTION=true
if [ -f "${MAIN_ZIPS_STAGING_DIR}/${INFA_SERVER_INSTALLER_ARCHIVE}" ] && [ -f "${INFA_DOWNLOAD_DIR}/${INFA_LICENSE_KEY_NAME}" ]; then
    log_message "$SCRIPT_NAME" "Server installer archive and license key already available. Skipping DAC extraction." "INFO"
    NEEDS_DAC_EXTRACTION=false
fi

if $NEEDS_DAC_EXTRACTION; then
    log_message "$SCRIPT_NAME" "Preparing local workspace for DAC extraction at ${LOCAL_WORK_BASE}." "INFO"
    sudo rm -rf "${LOCAL_WORK_BASE}" 2>/dev/null || true
    mkdir -p "${LOCAL_DAC_PARTS_DIR}" "${LOCAL_DAC_EXTRACT_DIR}"

    log_message "$SCRIPT_NAME" "Verifying DAC multi-part files in ${MAIN_ZIPS_STAGING_DIR}." "INFO"
    dac_base_name="dac_win_11g_infa_linux_64bit_951"
    missing_parts=()
    for ext in z01 z02 z03 zip; do
        part_file_src="${MAIN_ZIPS_STAGING_DIR}/${dac_base_name}.${ext}"
        if [ ! -f "$part_file_src" ]; then
            missing_parts+=("${dac_base_name}.${ext}")
        fi
    done
    if [ ${#missing_parts[@]} -gt 0 ]; then
        log_message "$SCRIPT_NAME" "Missing DAC archive parts: ${missing_parts[*]}" "ERROR"
        log_message "$SCRIPT_NAME" "All parts (.z01, .z02, .z03, .zip) must be present in ${MAIN_ZIPS_STAGING_DIR}." "ERROR"
        exit 1
    fi

    log_message "$SCRIPT_NAME" "Copying DAC parts to local workspace..." "INFO"
    for ext in z01 z02 z03 zip; do
        src="${MAIN_ZIPS_STAGING_DIR}/${dac_base_name}.${ext}"
        if ! cp -f "$src" "${LOCAL_DAC_PARTS_DIR}/"; then
            log_message "$SCRIPT_NAME" "Failed to copy $src to ${LOCAL_DAC_PARTS_DIR}" "ERROR"
            exit 1
        fi
    done

    # Extract using .zip as entry point to avoid 7z issues on .z01
    log_message "$SCRIPT_NAME" "Extracting split ZIP locally using 7z (entry: ${dac_base_name}.zip)..." "INFO"
    (cd "${LOCAL_DAC_PARTS_DIR}" && 7z x "${dac_base_name}.zip" -o"${LOCAL_DAC_EXTRACT_DIR}" -y) >> "$LOG_FILE" 2>&1 || {
        log_message "$SCRIPT_NAME" "7z extraction failed, attempting unzip fallback..." "WARN"
        (cd "${LOCAL_DAC_PARTS_DIR}" && unzip -o "${dac_base_name}.zip" -d "${LOCAL_DAC_EXTRACT_DIR}") >> "$LOG_FILE" 2>&1 || {
            log_message "$SCRIPT_NAME" "Failed to extract DAC archive with both 7z and unzip." "ERROR"
            exit 1
        }
    }

    if [ ! -d "${LOCAL_DAC_EXTRACT_DIR}" ] || [ -z "$(ls -A "${LOCAL_DAC_EXTRACT_DIR}" 2>/dev/null)" ]; then
        log_message "$SCRIPT_NAME" "Local DAC extraction directory is empty after extraction." "ERROR"
        exit 1
    fi
    log_message "$SCRIPT_NAME" "Local DAC extraction completed successfully." "INFO"
fi


# Extract the actual server installer archive if not already done
if [ ! -f "${SERVER_INSTALLER_PAYLOAD_DIR}/install.sh" ]; then
    log_message "$SCRIPT_NAME" "Server installer payload (install.sh) not found. Preparing extraction of server installer archive." "INFO"
    mkdir -p "$SERVER_INSTALLER_PAYLOAD_DIR"
    sudo rm -rf "${SERVER_INSTALLER_PAYLOAD_DIR:?}"/* 2>/dev/null || true

    # Find the server installer archive from local extracted contents first, then staging root
    SERVER_INSTALLER_ARCHIVE_PATH=""
    if [ -d "${LOCAL_DAC_EXTRACT_DIR}" ]; then
        SERVER_INSTALLER_ARCHIVE_PATH=$(find "${LOCAL_DAC_EXTRACT_DIR}" -name "${INFA_SERVER_INSTALLER_ARCHIVE}" -print -quit || true)
    fi
    if [ -z "$SERVER_INSTALLER_ARCHIVE_PATH" ]; then
        SERVER_INSTALLER_ARCHIVE_PATH=$(find "${MAIN_ZIPS_STAGING_DIR}" -maxdepth 1 -name "${INFA_SERVER_INSTALLER_ARCHIVE}" -print -quit || true)
    fi

    if [ -z "$SERVER_INSTALLER_ARCHIVE_PATH" ] || [ ! -f "$SERVER_INSTALLER_ARCHIVE_PATH" ]; then
        log_message "$SCRIPT_NAME" "Informatica Server installer archive '${INFA_SERVER_INSTALLER_ARCHIVE}' not found in local extracted contents or staging root." "ERROR"
        log_message "$SCRIPT_NAME" "Contents of ${MAIN_ZIPS_STAGING_DIR}:" "INFO"
        ls -la "${MAIN_ZIPS_STAGING_DIR}" >> "$LOG_FILE" 2>&1 || true
        exit 1
    fi

    log_message "$SCRIPT_NAME" "Found server installer archive at: ${SERVER_INSTALLER_ARCHIVE_PATH}" "INFO"
    log_message "$SCRIPT_NAME" "Extracting server installer payload to ${SERVER_INSTALLER_PAYLOAD_DIR}..." "INFO"

    if [[ "${SERVER_INSTALLER_ARCHIVE_PATH}" == *.tar.gz ]]; then
        if ! exec_cmd "$SCRIPT_NAME" "tar xzf \"${SERVER_INSTALLER_ARCHIVE_PATH}\" -C \"${SERVER_INSTALLER_PAYLOAD_DIR}\"" \
            "Successfully extracted server installer payload." \
            "Failed to extract server installer payload."; then
            exit 1
        fi
    elif [[ "${SERVER_INSTALLER_ARCHIVE_PATH}" == *.tar ]]; then
        if ! exec_cmd "$SCRIPT_NAME" "tar xf \"${SERVER_INSTALLER_ARCHIVE_PATH}\" -C \"${SERVER_INSTALLER_PAYLOAD_DIR}\"" \
            "Successfully extracted server installer payload." \
            "Failed to extract server installer payload."; then
            exit 1
        fi
    elif [[ "${SERVER_INSTALLER_ARCHIVE_PATH}" == *.zip ]]; then
        if ! exec_cmd "$SCRIPT_NAME" "unzip -o \"${SERVER_INSTALLER_ARCHIVE_PATH}\" -d \"${SERVER_INSTALLER_PAYLOAD_DIR}\"" \
            "Successfully extracted server installer payload." \
            "Failed to extract server installer payload."; then
            exit 1
        fi
    else
        log_message "$SCRIPT_NAME" "Unsupported server installer archive format: ${SERVER_INSTALLER_ARCHIVE_PATH}. Expected .tar, .tar.gz or .zip." "ERROR"
        exit 1
    fi

    if [ ! -f "${SERVER_INSTALLER_PAYLOAD_DIR}/install.sh" ]; then
        log_message "$SCRIPT_NAME" "Main installer script 'install.sh' not found in ${SERVER_INSTALLER_PAYLOAD_DIR} after extraction." "ERROR"
        log_message "$SCRIPT_NAME" "Contents of ${SERVER_INSTALLER_PAYLOAD_DIR}:" "INFO"
        ls -la "${SERVER_INSTALLER_PAYLOAD_DIR}" >> "$LOG_FILE"
        exit 1
    fi
    log_message "$SCRIPT_NAME" "Server installer payload extracted successfully." "INFO"
else
    log_message "$SCRIPT_NAME" "Server installer payload (install.sh) already exists. Skipping extraction." "INFO"
fi


# Locate and prepare the license key if not already in the final spot
FINAL_LICENSE_KEY_PATH="${INFA_DOWNLOAD_DIR}/${INFA_LICENSE_KEY_NAME}"
if [ -f "$FINAL_LICENSE_KEY_PATH" ]; then
    log_message "$SCRIPT_NAME" "License key ${INFA_LICENSE_KEY_NAME} already exists in ${INFA_DOWNLOAD_DIR}. Skipping copy from staging." "INFO"
else
    log_message "$SCRIPT_NAME" "License key not found at ${FINAL_LICENSE_KEY_PATH}. Searching locally extracted contents first, then staging..." "INFO"
    LICENSE_KEY_PATH_STAGING=""
    if [ -d "${LOCAL_DAC_EXTRACT_DIR}" ]; then
        LICENSE_KEY_PATH_STAGING=$(find "${LOCAL_DAC_EXTRACT_DIR}" -name "${INFA_LICENSE_KEY_NAME}" -print -quit || true)
    fi
    if [ -z "$LICENSE_KEY_PATH_STAGING" ]; then
        LICENSE_KEY_PATH_STAGING=$(find "${MAIN_ZIPS_STAGING_DIR}" -name "${INFA_LICENSE_KEY_NAME}" -print -quit || true)
    fi

    if [ -f "$LICENSE_KEY_PATH_STAGING" ]; then
        log_message "$SCRIPT_NAME" "Found license key at ${LICENSE_KEY_PATH_STAGING}. Copying to ${FINAL_LICENSE_KEY_PATH}." "INFO"
        if ! exec_cmd "$SCRIPT_NAME" "cp \"${LICENSE_KEY_PATH_STAGING}\" \"${FINAL_LICENSE_KEY_PATH}\"" \
            "Copied license key." \
            "Failed to copy license key."; then
            exit 1
        fi
    else
        log_message "$SCRIPT_NAME" "Informatica License Key '${INFA_LICENSE_KEY_NAME}' not found in local extraction or staging. Please ensure the license key file is available." "ERROR"
        exit 1
    fi
fi

# Cleanup local temporary workspace
if [ -d "${LOCAL_WORK_BASE}" ]; then
    log_message "$SCRIPT_NAME" "Cleaning up local workspace at ${LOCAL_WORK_BASE}..." "INFO"
    sudo rm -rf "${LOCAL_WORK_BASE}" || true
fi

log_message "$SCRIPT_NAME" "Informatica installer preparation completed." "INFO"
exit 0