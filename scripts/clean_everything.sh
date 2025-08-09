#!/bin/bash

# clean_everything.sh
# Properly uninstalls and cleans all components while preserving downloads
# PRESERVES: /opt/Informatica/downloads (all ZIP files, license key, JDK archive, SQL Developer RPM)

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

log_message "$SCRIPT_NAME" "Starting comprehensive cleanup. Downloads will be preserved in ${DOWNLOAD_DIR}." "INFO"

# 1) Stop and uninstall Informatica Server properly
if [ -d "${INFA_HOME}" ] && [ -f "${INFA_HOME}/tomcat/bin/infaservice.sh" ]; then
  log_message "$SCRIPT_NAME" "Stopping Informatica services..." "INFO"
  
  # Stop services
  "${INFA_HOME}/tomcat/bin/infaservice.sh" stop >> "$LOG_FILE" 2>&1 || true
  sleep 5
  
  # Kill any remaining Informatica processes
  pkill -f "informatica\|pmserver\|pmrepagent" 2>/dev/null || true
  
  # Look for uninstall script and use it if available
  UNINSTALL_SCRIPT=""
  for uninstaller in \
    "${INFA_HOME}/uninstall/uninstall.sh" \
    "${INFA_HOME}/Uninstall_Informatica_9.5.1_HotFix_2/uninstall.sh" \
    "${INFA_HOME}/../Uninstall_Informatica_9.5.1_HotFix_2/uninstall.sh"; do
    if [ -f "$uninstaller" ]; then
      UNINSTALL_SCRIPT="$uninstaller"
      break
    fi
  done
  
  if [ -n "$UNINSTALL_SCRIPT" ]; then
    log_message "$SCRIPT_NAME" "Running Informatica uninstaller: $UNINSTALL_SCRIPT" "INFO"
    # Run uninstaller in silent mode if possible
    "$UNINSTALL_SCRIPT" -i silent >> "$LOG_FILE" 2>&1 || true
  else
    log_message "$SCRIPT_NAME" "No uninstaller found, will remove directories manually." "WARN"
  fi
fi

# 2) Remove Informatica installation (but preserve downloads)
if [ -d "${INFA_INSTALL_BASE_DIR}" ]; then
  if confirm "Remove Informatica installation at ${INFA_INSTALL_BASE_DIR} (preserving downloads)?"; then
    log_message "$SCRIPT_NAME" "Removing Informatica installation while preserving downloads..." "INFO"
    
    # Remove everything under /opt/Informatica except downloads
    for item in "${INFA_INSTALL_BASE_DIR}"/*; do
      if [ -e "$item" ] && [ "$(basename "$item")" != "downloads" ]; then
        log_message "$SCRIPT_NAME" "Removing: $item" "INFO"
        sudo rm -rf "$item" || true
      fi
    done
    
    # Clean up any Informatica-related directories elsewhere
    sudo rm -rf /var/informatica /tmp/informatica* /tmp/Informatica* 2>/dev/null || true
  fi
fi

# 3) Remove temp install workspace
if [ -d "${TEMP_INSTALL_DIR}" ]; then
  log_message "$SCRIPT_NAME" "Removing temporary install workspace ${TEMP_INSTALL_DIR}..." "INFO"
  sudo rm -rf "${TEMP_INSTALL_DIR}" || true
fi

# 4) Uninstall SQL Developer properly
if rpm -q sqldeveloper >/dev/null 2>&1; then
  if confirm "Uninstall SQL Developer RPM package?"; then
    log_message "$SCRIPT_NAME" "Uninstalling SQL Developer RPM..." "INFO"
    sudo yum remove -y sqldeveloper >> "$LOG_FILE" 2>&1 || sudo rpm -e sqldeveloper >> "$LOG_FILE" 2>&1 || true
  fi
fi

# Remove SQL Developer directories and launcher
for sqldev_dir in /opt/sqldeveloper /usr/local/sqldeveloper; do
  if [ -d "$sqldev_dir" ]; then
    log_message "$SCRIPT_NAME" "Removing SQL Developer directory: $sqldev_dir" "INFO"
    sudo rm -rf "$sqldev_dir" || true
  fi
done

# Remove SQL Developer launcher
if [ -f /usr/local/bin/sqldeveloper ]; then
  log_message "$SCRIPT_NAME" "Removing SQL Developer launcher..." "INFO"
  sudo rm -f /usr/local/bin/sqldeveloper || true
fi

# Remove SQL Developer user config
if [ -d "${SQLDEV_CONFIG_DIR}" ]; then
  log_message "$SCRIPT_NAME" "Removing SQL Developer user config ${SQLDEV_CONFIG_DIR}..." "INFO"
  rm -rf "${SQLDEV_CONFIG_DIR}" || true
fi

# 5) Remove JDK installation
if [ -d "${JDK_INSTALL_DIR}" ]; then
  if confirm "Remove JDK installation under ${JDK_INSTALL_DIR}?"; then
    log_message "$SCRIPT_NAME" "Removing JDK installation..." "INFO"
    sudo rm -rf "${JDK_INSTALL_DIR}" || true
    
    # Remove Java alternatives
    if command -v update-alternatives >/dev/null 2>&1; then
      sudo update-alternatives --remove-all java >/dev/null 2>&1 || true
      sudo update-alternatives --remove-all javac >/dev/null 2>&1 || true
    fi
  fi
fi

# 6) Remove profile scripts
for prof in /etc/profile.d/jdk.sh /etc/profile.d/informatica.sh /etc/profile.d/oracle_xe.sh; do
  if [ -f "$prof" ]; then
    log_message "$SCRIPT_NAME" "Removing profile script $prof" "INFO"
    sudo rm -f "$prof" || true
  fi
done

# 7) Clean Oracle XE Docker completely
if command -v docker >/dev/null 2>&1; then
  log_message "$SCRIPT_NAME" "Cleaning Oracle XE Docker resources..." "INFO"
  
  # Stop and remove container
  docker stop oracle-xe 2>/dev/null || true
  docker rm oracle-xe 2>/dev/null || true
  
  # Remove volumes
  docker volume rm informatica_automation_rl8_oracle_data 2>/dev/null || true
  
  # Remove networks
  docker network rm informatica_automation_rl8_default 2>/dev/null || true
  
  # Remove Oracle XE image if present
  if confirm "Remove Oracle XE Docker image (saves disk space)?"; then
    docker rmi gvenzl/oracle-xe:11.2.0.2-slim 2>/dev/null || true
    docker rmi $(docker images -q --filter "reference=*oracle*") 2>/dev/null || true
  fi
  
  # Clean up orphaned Docker resources
  docker system prune -f >/dev/null 2>&1 || true
fi

# 8) Clean repo-generated files
log_message "$SCRIPT_NAME" "Cleaning repo-generated files (logs, response files)..." "INFO"
rm -rf "${LOG_DIR}"/* 2>/dev/null || true
rm -rf "${INFA_RESPONSE_FILES_DIR}"/* 2>/dev/null || true

# 9) Remove hosts entries for infa-server
if grep -q "infa-server" /etc/hosts 2>/dev/null; then
  log_message "$SCRIPT_NAME" "Removing infa-server from /etc/hosts..." "INFO"
  sudo sed -i '/infa-server/d' /etc/hosts || true
fi

# 10) Remove firewall rules for Informatica ports
if command -v firewall-cmd >/dev/null 2>&1; then
  if sudo firewall-cmd --state >/dev/null 2>&1; then
    log_message "$SCRIPT_NAME" "Removing Informatica firewall rules..." "INFO"
    sudo firewall-cmd --remove-port=6005-6010/tcp --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --remove-port=6008/tcp --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
  fi
fi

# 11) Unset environment variables for current shell
log_message "$SCRIPT_NAME" "Unsetting Informatica/Oracle/JDK environment variables..." "INFO"

# Informatica variables
unset INFA_HOME INFA_NODE_NAME INFA_DOMAINS_FILE INFORMATICA_HOME || true
unset INFA_INSTALL_BASE_DIR INFA_VERSION INFA_DOMAIN_NAME || true
unset INFA_ADMIN_USER INFA_ADMIN_PASS INFA_SITE_KEY_PASSWORD || true
unset INFA_NODE_HOST INFA_STATIC_HOSTNAME || true
unset INFA_DOM_USER INFA_DOM_PASS INFA_REP_USER INFA_REP_PASS || true
unset INFA_HR_USER INFA_HR_PASS || true
unset INFA_DOMAIN_DB_HOST INFA_DOMAIN_DB_PORT INFA_DOMAIN_DB_SERVICE_NAME || true
unset INFA_REPO_SERVICE_NAME INFA_INT_SERVICE_NAME INFA_DEFAULT_CODE_PAGE || true
unset INFA_SERVER_INSTALLER_ARCHIVE INFA_LICENSE_KEY_NAME || true

# Java variables
unset JAVA_HOME JAVA_HOME_PATH JDK_INSTALL_DIR JDK_VERSION_NAME || true

# Oracle variables
unset ORACLE_CONTAINER_NAME ORACLE_BASE ORACLE_HOME_DOCKER ORACLE_SID || true
unset ORACLE_LISTENER_PORT ORACLE_HTTP_PORT ORACLE_HOST || true
unset ORACLE_SYS_PASSWORD ORACLE_SYSTEM_PASSWORD ORACLE_SYSDBA_USER || true

# SQL Developer variables
unset SQLDEV_RPM_NAME SQLDEV_INSTALL_PATH SQLDEV_CONFIG_DIR SQLDEV_CONNECTIONS_FILE || true

# Path and directory variables
unset DOWNLOAD_DIR TEMP_INSTALL_DIR INFA_RESPONSE_FILES_DIR LOG_DIR || true
unset AUTOMATION_BASE_DIR SCRIPTS_DIR MAIN_LOG_FILE || true
unset DOCKER_COMPOSE_FILE OPEN_CURSORS_TARGET || true

# 12) Clean up any remaining processes
log_message "$SCRIPT_NAME" "Cleaning up any remaining processes..." "INFO"
pkill -f "oracle\|informatica\|pmserver\|pmrepagent\|infaservice" 2>/dev/null || true

# 13) Verify downloads are preserved
log_message "$SCRIPT_NAME" "Verifying downloads are preserved..." "INFO"
if [ -d "${DOWNLOAD_DIR}" ]; then
  PRESERVED_COUNT=$(find "${DOWNLOAD_DIR}" -type f 2>/dev/null | wc -l)
  log_message "$SCRIPT_NAME" "Downloads preserved: ${PRESERVED_COUNT} files in ${DOWNLOAD_DIR}" "INFO"
  
  # List what's preserved
  find "${DOWNLOAD_DIR}" -type f 2>/dev/null | while read -r file; do
    log_message "$SCRIPT_NAME" "Preserved: $file" "INFO"
  done
else
  log_message "$SCRIPT_NAME" "Downloads directory not found - nothing to preserve." "WARN"
fi

log_message "$SCRIPT_NAME" "Comprehensive cleanup completed. Downloads preserved in ${DOWNLOAD_DIR}." "INFO"
echo ""
echo "Summary:"
echo "- Informatica Server: Uninstalled (preserving downloads)"
echo "- SQL Developer: Uninstalled"
echo "- JDK: Removed (if confirmed)"
echo "- Oracle XE Docker: Containers/volumes removed"
echo "- Environment variables: Unset for current shell"
echo "- Firewall rules: Removed"
echo "- Profile scripts: Removed"
echo ""
echo "PRESERVED: All files under ${DOWNLOAD_DIR}"
echo ""
echo "For complete cleanup, reboot or start a new shell session."
exit 0