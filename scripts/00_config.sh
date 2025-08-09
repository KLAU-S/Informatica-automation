#!/bin/bash

# 00_config.sh
# Configuration file for the Informatica installation automation

# --- Project Paths ---
export AUTOMATION_BASE_DIR="/mnt/hgfs/rocky/informatica_automation_rl8"
export DOWNLOAD_DIR="/opt/Informatica/downloads"
export SCRIPTS_DIR="${AUTOMATION_BASE_DIR}/scripts"
export LOG_DIR="${AUTOMATION_BASE_DIR}/logs"
export TEMP_INSTALL_DIR="/opt/temp_install_files"
export INFA_RESPONSE_FILES_DIR="${AUTOMATION_BASE_DIR}/informatica_response_files"

export MAIN_LOG_FILE="${LOG_DIR}/informatica_install_$(date '+%Y%m%d_%H%M%S').log"

# --- JDK Configuration (JavaFX-enabled) -----------------------------
export JDK_ARCHIVE_NAME="zulu8.74.0.17-ca-fx-jdk8.0.392-linux_x64.tar.gz"
export JDK_DOWNLOAD_URL="https://cdn.azul.com/zulu/bin/${JDK_ARCHIVE_NAME}"
export JDK_INSTALL_DIR="/opt/java"
export JDK_VERSION_NAME="zulu8.74.0.17-ca-fx-jdk8.0.392-linux_x64"
# Define JAVA_HOME_PATH as used by 02_install_jdk.sh
export JAVA_HOME_PATH="${JDK_INSTALL_DIR}/${JDK_VERSION_NAME}"

# Also define JAVA_HOME for general compatibility and for PATH setting below
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="${JAVA_HOME}/bin:${PATH}"

# --- Oracle XE Configuration (Docker) ---
export ORACLE_CONTAINER_NAME="oracle-xe"
export ORACLE_BASE="/u01/app/oracle"
# ORACLE_HOME inside the container. Not strictly needed on the host for Informatica,
# but good for reference if you exec into the container.
export ORACLE_HOME_DOCKER="${ORACLE_BASE}/product/11.2.0/xe"
export ORACLE_SID="XE"
export ORACLE_LISTENER_PORT="1521"
export ORACLE_HTTP_PORT="8080" # Changed to match docker-compose.yml
export ORACLE_HOST="localhost" # Hostname *from the perspective of the host machine* to connect to Oracle

# Oracle Docker credentials
export ORACLE_SYS_PASSWORD="oracle"  # As defined in docker-compose.yml
export ORACLE_SYSTEM_PASSWORD="oracle"  # Same as SYS for simplicity
export ORACLE_SYSDBA_USER="SYS"

# --- SQL Developer Configuration ---
export SQLDEV_RPM_NAME="sqldeveloper-21.4.3-063.0100.noarch.rpm"
export SQLDEV_INSTALL_PATH="/opt/sqldeveloper"
export SQLDEV_CONFIG_DIR="$HOME/.sqldeveloper"
export SQLDEV_CONNECTIONS_FILE="${SQLDEV_CONFIG_DIR}/system21.4.3.063.0100/o.jdeveloper.db.connection.12.2.1.4.42.170908.1359/connections.xml"

# --- Informatica Users & Database Details (Oracle) ---
export INFA_DOM_USER="INFA_DOM"
export INFA_DOM_PASS="INFA_DOM"
export INFA_REP_USER="INFA_REP"
export INFA_REP_PASS="INFA_REP"
export INFA_HR_USER="HR"
export INFA_HR_PASS="HR"

# --- Informatica Server Configuration ---
export INFA_SERVER_INSTALLER_ARCHIVE="951HF2_Server_Installer_linux-x64.tar"
export INFA_LICENSE_KEY_NAME="Oracle_All_OS_Prod.key"

export INFA_INSTALL_BASE_DIR="/opt/Informatica"
export INFA_VERSION="9.5.1"
export INFA_HOME="${INFA_INSTALL_BASE_DIR}/${INFA_VERSION}"

# *** CRITICAL CHANGE & RECOMMENDATION: INFA_NODE_HOST ***
# This should be the hostname that Informatica services will use to identify this machine.
# It MUST be resolvable (ideally via /etc/hosts and DNS if applicable) to a non-loopback IP.
# Let's use a specific, static hostname. You'll need to ensure this name is in /etc/hosts
# mapped to your primary server IP (e.g., 192.168.110.133).
# Using `$(hostname)` can be problematic if the system hostname isn't set ideally for services.
export INFA_STATIC_HOSTNAME="infa-server" # Example: Choose a name
export INFA_NODE_HOST="${INFA_STATIC_HOSTNAME}" # Use the static name

# *** RECOMMENDATION: Domain and Node Names ***
# Keep them simple and avoid special characters or dynamically changing parts from `$(hostname)` if `hostname` is not stable or ideal.
# Using the static hostname here is good for consistency.
export INFA_DOMAIN_NAME="Domain_${INFA_STATIC_HOSTNAME}"
export INFA_NODE_NAME="Node_${INFA_STATIC_HOSTNAME}"
# Alternatively, if you want simpler names not tied to the hostname:
# export INFA_DOMAIN_NAME="InfaDomain01"
# export INFA_NODE_NAME="Node01"
# Just ensure INFA_NODE_HOST is set correctly. The values above are good if INFA_STATIC_HOSTNAME is well-defined.

export INFA_ADMIN_USER="Administrator"
export INFA_ADMIN_PASS="Administrator"
export INFA_SITE_KEY_PASSWORD="SiteKeyPassword123"

export INFA_DOMAIN_DB_HOST="${ORACLE_HOST}" # This is 'localhost' as Oracle is Dockerized and port-mapped
export INFA_DOMAIN_DB_PORT="${ORACLE_LISTENER_PORT}"
export INFA_DOMAIN_DB_SERVICE_NAME="${ORACLE_SID}"

# *** RECOMMENDATION: Repository and Integration Service Names ***
# Similar to Domain/Node names, using the static hostname makes them predictable.
export INFA_REPO_SERVICE_NAME="repsrvc_${INFA_STATIC_HOSTNAME}"
export INFA_INT_SERVICE_NAME="intsrvc_${INFA_STATIC_HOSTNAME}"
# Or simpler fixed names:
# export INFA_REPO_SERVICE_NAME="RepoSvc01"
# export INFA_INT_SERVICE_NAME="IntSvc01"

export INFA_DEFAULT_CODE_PAGE="MS Windows Latin 1 (ANSI), superset of Latin1"

# --- System Settings ---
export OPEN_CURSORS_TARGET=1000

# --- Docker Settings ---
export DOCKER_COMPOSE_FILE="${AUTOMATION_BASE_DIR}/docker-compose.yml"

# --- NAT/Networking Settings ---
# For NAT access from Windows host to Rocky VM:
# - Services generally bind to all interfaces by default. If needed, set bind address below.
# - External clients should use the VM's IP (e.g., NAT adapter IP) or a hosts entry mapping 'infa-server' to that IP.
# - Internally, scripts use localhost to communicate with the gateway.
export INFA_BIND_ADDRESS="0.0.0.0"           # Bind address hint for services (where applicable)
export INFA_PUBLISH_HOST="${INFA_STATIC_HOSTNAME}"  # Hostname clients will use (set to VM IP or DNS name if desired)

# Load logging utilities
# Ensure this path is correct and the file exists
if [ -f "${SCRIPTS_DIR}/lib/logging_utils.sh" ]; then
    source "${SCRIPTS_DIR}/lib/logging_utils.sh"
else
    echo "WARNING: logging_utils.sh not found at ${SCRIPTS_DIR}/lib/logging_utils.sh"
    # Define a placeholder log_message function if the utility is missing
    log_message() {
        local script_name="$1"
        local message="$2"
        local level="${3:-INFO}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [${level}] [${script_name}]: ${message}"
    }
fi