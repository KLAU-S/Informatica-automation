#!/bin/bash

# clean_everything.sh
# Reverts the system to pre-automation state by removing installed/configured components
# Keeps large downloaded artifacts under /opt/Informatica/downloads intact

set -euo pipefail

source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="clean_everything"

# Ensure logging initialized
if [ -z "${LOG_FILE:-}" ] || [ ! -f "${LOG_FILE:-/dev/null}" ]; then
  init_logging "$MAIN_LOG_FILE"
fi

confirm() {
  read -r -p "$1 [y/N]: " reply || true
  case "$reply" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

log_message "$SCRIPT_NAME" "Starting cleanup. Large downloads will be preserved in ${DOWNLOAD_DIR}." "INFO"

# 1) Stop Informatica services if present
if [ -x "${INFA_HOME}/tomcat/bin/infaservice.sh" ]; then
  log_message "$SCRIPT_NAME" "Stopping Informatica services..." "INFO"
  ${INFA_HOME}/tomcat/bin/infaservice.sh stop >> "$LOG_FILE" 2>&1 || true
fi

# 2) Remove Informatica installation directories
if [ -d "${INFA_INSTALL_BASE_DIR}" ]; then
  if confirm "Remove Informatica installation at ${INFA_INSTALL_BASE_DIR} (but keep ${DOWNLOAD_DIR})?"; then
    BASE_DIR="${INFA_INSTALL_BASE_DIR}"
    DL_DIR="${DOWNLOAD_DIR}"

    # Resolve to absolute paths where possible
    if command -v realpath >/dev/null 2>&1; then
      BASE_DIR_ABS="$(realpath -m "$BASE_DIR")"
      DL_DIR_ABS="$(realpath -m "$DL_DIR")"
    else
      BASE_DIR_ABS="$BASE_DIR"
      DL_DIR_ABS="$DL_DIR"
    fi

    # If downloads directory exists and is inside base dir, preserve it by deleting siblings only
    if [ -d "$DL_DIR_ABS" ] && [[ "$DL_DIR_ABS" == "$BASE_DIR_ABS"/* ]]; then
      log_message "$SCRIPT_NAME" "Preserving downloads at $DL_DIR_ABS and removing other contents under $BASE_DIR_ABS..." "INFO"
      # Remove all first-level entries under base except the downloads directory
      # Use find for robustness and avoid touching the preserved directory
      sudo find "$BASE_DIR_ABS" -mindepth 1 -maxdepth 1 \
        -not -path "$DL_DIR_ABS" \
        -exec rm -rf {} + || true
      log_message "$SCRIPT_NAME" "Removed ${BASE_DIR_ABS} contents except ${DL_DIR_ABS}." "INFO"
    else
      # If downloads is elsewhere/not present, remove the base directory entirely
      sudo rm -rf "$BASE_DIR_ABS" || true
      log_message "$SCRIPT_NAME" "Removed ${BASE_DIR_ABS}. (No in-place downloads to preserve)" "INFO"
      # Recreate base dir to keep expected structure if needed later
      sudo mkdir -p "$BASE_DIR_ABS" || true
    fi
  fi
fi

# 3) Remove temp install workspace
if [ -d "${TEMP_INSTALL_DIR}" ]; then
  log_message "$SCRIPT_NAME" "Removing temporary install workspace ${TEMP_INSTALL_DIR}..." "INFO"
  sudo rm -rf "${TEMP_INSTALL_DIR}" || true
fi

# 4) Remove profile scripts
for prof in /etc/profile.d/jdk.sh /etc/profile.d/informatica.sh; do
  if [ -f "$prof" ]; then
    log_message "$SCRIPT_NAME" "Removing profile script $prof" "INFO"
    sudo rm -f "$prof" || true
  fi
done

# 5) Remove JDK installation
if [ -d "${JDK_INSTALL_DIR}" ]; then
  if confirm "Remove JDK under ${JDK_INSTALL_DIR}?"; then
    sudo rm -rf "${JDK_INSTALL_DIR}" || true
    log_message "$SCRIPT_NAME" "Removed JDK directory ${JDK_INSTALL_DIR}." "INFO"
  fi
fi

# 6) Remove SQL Developer (optional)
if [ -d "${SQLDEV_INSTALL_PATH}" ]; then
  if confirm "Remove SQL Developer under ${SQLDEV_INSTALL_PATH}?"; then
    sudo rm -rf "${SQLDEV_INSTALL_PATH}" || true
    log_message "$SCRIPT_NAME" "Removed SQL Developer at ${SQLDEV_INSTALL_PATH}." "INFO"
  fi
fi

# 7) Remove SQL Developer user config
if [ -d "${SQLDEV_CONFIG_DIR}" ]; then
  log_message "$SCRIPT_NAME" "Removing SQL Developer user config ${SQLDEV_CONFIG_DIR}..." "INFO"
  rm -rf "${SQLDEV_CONFIG_DIR}" || true
fi

# 8) Oracle XE Docker: stop and remove container + volumes
if command -v docker &> /dev/null; then
  log_message "$SCRIPT_NAME" "Cleaning Oracle XE Docker resources..." "INFO"
  "$(dirname "$0")/manage_oracle_docker.sh" clean || true
fi

# 9) Clean repo-generated files
log_message "$SCRIPT_NAME" "Cleaning repo-generated files (logs, response files)..." "INFO"
rm -rf "${LOG_DIR}"/* || true
rm -rf "${INFA_RESPONSE_FILES_DIR}"/* || true

# 10) Remove any leftover symlinks or alternatives for Java
if command -v update-alternatives &> /dev/null; then
  log_message "$SCRIPT_NAME" "Cleaning Java alternatives (best-effort)..." "INFO"
  sudo update-alternatives --remove-all java >/dev/null 2>&1 || true
  sudo update-alternatives --remove-all javac >/dev/null 2>&1 || true
fi

# 11) Unset environment variables and remove profile scripts related to Informatica/Oracle/JDK (best-effort)
log_message "$SCRIPT_NAME" "Unsetting environment variables for current shell (best-effort)." "INFO"
unset INFA_HOME INFA_NODE_NAME INFA_DOMAINS_FILE INFORMATICA_HOME || true
unset INFA_INSTALL_BASE_DIR INFA_VERSION INFA_DOMAIN_NAME INFA_ADMIN_USER INFA_ADMIN_PASS || true
unset INFA_NODE_HOST INFA_DOM_USER INFA_DOM_PASS INFA_REP_USER INFA_REP_PASS INFA_HR_USER INFA_HR_PASS || true
unset INFA_DOMAIN_DB_HOST INFA_DOMAIN_DB_PORT INFA_DOMAIN_DB_SERVICE_NAME || true
unset JAVA_HOME JAVA_HOME_PATH JDK_INSTALL_DIR PATH || true
unset DOWNLOAD_DIR TEMP_INSTALL_DIR INFA_RESPONSE_FILES_DIR LOG_DIR || true

log_message "$SCRIPT_NAME" "Cleanup completed. Downloads preserved in ${DOWNLOAD_DIR}." "INFO"
echo "If you want a fully clean slate, reboot or re-login to clear any lingering env from current shell."
exit 0


