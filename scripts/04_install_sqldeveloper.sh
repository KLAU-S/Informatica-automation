#!/bin/bash

# 04_install_sqldeveloper.sh
# Installs SQL Developer from RPM.

source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="04_install_sqldev"
log_message "$SCRIPT_NAME" "Starting SQL Developer installation process." "INFO"

SQLDEV_PACKAGE_NAME=$(rpm -qpi "${DOWNLOAD_DIR}/sqldeveloper/${SQLDEV_RPM_NAME}" 2>/dev/null | grep -E '^Name\s+:' | awk '{print $3}')
if [ -z "$SQLDEV_PACKAGE_NAME" ]; then
    log_message "$SCRIPT_NAME" "Could not determine package name from RPM file ${SQLDEV_RPM_NAME}. Assuming base name." "WARN"
    SQLDEV_PACKAGE_NAME="${SQLDEV_RPM_NAME%.noarch.rpm}" # Fallback to filename based
fi
log_message "$SCRIPT_NAME" "SQL Developer package name identified as: ${SQLDEV_PACKAGE_NAME}" "INFO"


if sudo rpm -q "${SQLDEV_PACKAGE_NAME}" &> /dev/null; then
    log_message "$SCRIPT_NAME" "SQL Developer package (${SQLDEV_PACKAGE_NAME}) appears to be already installed." "INFO"
    if [ -x "${SQLDEV_INSTALL_PATH}/sqldeveloper.sh" ]; then
         log_message "$SCRIPT_NAME" "SQL Developer executable found at ${SQLDEV_INSTALL_PATH}/sqldeveloper.sh." "INFO"
         log_message "$SCRIPT_NAME" "SQL Developer installation skipped." "INFO"
         exit 0
    else
        log_message "$SCRIPT_NAME" "SQL Developer package installed, but main script not found at expected location ${SQLDEV_INSTALL_PATH}/sqldeveloper.sh. This is unusual." "WARN"
        # Proceed to ensure config is correct if it exists, or attempt re-install if path is wrong.
        # For now, we'll assume if RPM is there, it's mostly fine, but user should verify path.
    fi
fi

SQLDEV_RPM_FILE_PATH="${DOWNLOAD_DIR}/sqldeveloper/${SQLDEV_RPM_NAME}"
if [ ! -f "$SQLDEV_RPM_FILE_PATH" ]; then
    log_message "$SCRIPT_NAME" "SQL Developer RPM ${SQLDEV_RPM_FILE_PATH} not found. Please place it manually." "ERROR"
    exit 1
fi

log_message "$SCRIPT_NAME" "Verifying JDK for SQL Developer..." "INFO"
PROFILE_SCRIPT_JDK="/etc/profile.d/jdk.sh"
if [ -f "$PROFILE_SCRIPT_JDK" ]; then
    source "$PROFILE_SCRIPT_JDK"
else
    log_message "$SCRIPT_NAME" "JDK profile script ${PROFILE_SCRIPT_JDK} not found. SQL Developer might fail to install or run." "WARN"
fi

if ! command -v java &> /dev/null || ! [ -n "${JAVA_HOME:-}" ] || [ ! -d "${JAVA_HOME:-}" ]; then
    log_message "$SCRIPT_NAME" "Java (JAVA_HOME) is not properly configured. SQL Developer installation may fail or it may prompt for Java home." "ERROR"
    log_message "$SCRIPT_NAME" "Ensure JDK is installed and ${PROFILE_SCRIPT_JDK} is sourced." "ERROR"
    exit 1
fi
log_message "$SCRIPT_NAME" "Using JAVA_HOME=${JAVA_HOME}" "INFO"


log_message "$SCRIPT_NAME" "Installing SQL Developer from RPM: ${SQLDEV_RPM_FILE_PATH}..." "INFO"
if ! exec_cmd "$SCRIPT_NAME" "sudo yum localinstall -y \"${SQLDEV_RPM_FILE_PATH}\"" \
    "Successfully installed SQL Developer RPM." \
    "Failed to install SQL Developer RPM."; then
    exit 1
fi

# Verify SQL Developer executable path (RPM locations vary by release)
SQLDEV_EXEC_PATH="${SQLDEV_INSTALL_PATH}/sqldeveloper.sh" # Default target from config

# Helper: resolve installed path via RPM query
resolve_sqldev_path_via_rpm() {
    local pkg_name="$1"
    local path
    path=$(rpm -ql "$pkg_name" 2>/dev/null | grep -E '/(opt|usr)/.*/sqldeveloper(\.sh)?$' | head -n1 || true)
    if [ -z "$path" ]; then
        # Try common locations inside /opt tree including nested bin
        path=$(rpm -ql "$pkg_name" 2>/dev/null | grep -E '/opt/.*/sqldeveloper(\.sh)?$|/opt/.*/sqldeveloper/bin/sqldeveloper$' | head -n1 || true)
    fi
    echo "$path"
}

ensure_executable() {
    local file="$1"
    if [ -f "$file" ] && [ ! -x "$file" ]; then
        chmod +x "$file" 2>/dev/null || true
    fi
}

if [ ! -x "$SQLDEV_EXEC_PATH" ]; then
    # Try RPM query first
    CANDIDATE=$(resolve_sqldev_path_via_rpm "$SQLDEV_PACKAGE_NAME")
    if [ -n "$CANDIDATE" ]; then
        ensure_executable "$CANDIDATE"
        if [ -x "$CANDIDATE" ]; then
            log_message "$SCRIPT_NAME" "SQL Developer executable found via RPM at ${CANDIDATE}." "INFO"
            SQLDEV_EXEC_PATH="$CANDIDATE"
            SQLDEV_INSTALL_PATH=$(dirname "$SQLDEV_EXEC_PATH")
        fi
    fi
fi

if [ ! -x "$SQLDEV_EXEC_PATH" ]; then
    # Try to find it on disk without requiring executable bit
    SQLDEV_EXEC_PATH_FOUND=$(find /opt /usr -xdev -name sqldeveloper.sh -type f 2>/dev/null | head -n 1)
    if [ -z "$SQLDEV_EXEC_PATH_FOUND" ]; then
        # Some builds provide a wrapper named 'sqldeveloper' (no .sh) in bin
        SQLDEV_EXEC_PATH_FOUND=$(find /opt /usr -xdev -path '*/bin/sqldeveloper' -type f 2>/dev/null | head -n 1)
    fi
    if [ -n "$SQLDEV_EXEC_PATH_FOUND" ]; then
        ensure_executable "$SQLDEV_EXEC_PATH_FOUND"
        log_message "$SCRIPT_NAME" "SQL Developer launcher found at ${SQLDEV_EXEC_PATH_FOUND}." "INFO"
        SQLDEV_EXEC_PATH="$SQLDEV_EXEC_PATH_FOUND"
        SQLDEV_INSTALL_PATH=$(dirname "$SQLDEV_EXEC_PATH")
    fi
fi

if [ ! -x "$SQLDEV_EXEC_PATH" ]; then
    # As a last resort, check well-known wrapper locations
    for wrapper in /usr/local/bin/sqldeveloper /usr/bin/sqldeveloper; do
        if [ -f "$wrapper" ]; then
            ensure_executable "$wrapper"
            if [ -x "$wrapper" ]; then
                log_message "$SCRIPT_NAME" "SQL Developer wrapper detected at ${wrapper}." "INFO"
                SQLDEV_EXEC_PATH="$wrapper"
                SQLDEV_INSTALL_PATH=$(dirname "$SQLDEV_EXEC_PATH")
                break
            fi
        fi
    done
fi

if [ ! -x "$SQLDEV_EXEC_PATH" ]; then
    log_message "$SCRIPT_NAME" "SQL Developer installation might have failed or installed to an unexpected location. Expected launcher not found under ${SQLDEV_INSTALL_PATH} nor common paths. Try: rpm -ql ${SQLDEV_PACKAGE_NAME} | grep -i sqldeveloper" "ERROR"
    exit 1
fi

log_message "$SCRIPT_NAME" "SQL Developer installed. Executable confirmed at ${SQLDEV_EXEC_PATH}." "INFO"

# --- Configure Java Home for SQL Developer ---

# Function to update SetJavaHome in a given conf file
update_set_java_home() {
    local conf_file="$1"
    log_message "$SCRIPT_NAME" "Checking/Updating SetJavaHome in ${conf_file} for JDK: ${JAVA_HOME_PATH}" "INFO"

    local need_sudo="false"
    if [ ! -w "$(dirname "$conf_file")" ] || { [ -f "$conf_file" ] && [ ! -w "$conf_file" ]; }; then
        need_sudo="true"
    fi

    if [ ! -f "$conf_file" ]; then
        log_message "$SCRIPT_NAME" "Conf file ${conf_file} not found. Creating and setting JavaHome." "INFO"
        if [ "$need_sudo" = "true" ]; then
            sudo mkdir -p "$(dirname "${conf_file}")"
            echo "SetJavaHome ${JAVA_HOME_PATH}" | sudo tee "${conf_file}" > /dev/null
        else
            mkdir -p "$(dirname "${conf_file}")"
            echo "SetJavaHome ${JAVA_HOME_PATH}" > "${conf_file}"
        fi
        log_message "$SCRIPT_NAME" "Created ${conf_file} and set JavaHome." "INFO"
        return 0
    fi

    if grep -q "^SetJavaHome" "${conf_file}"; then
        if grep -q "^SetJavaHome ${JAVA_HOME_PATH}$" "${conf_file}"; then
            log_message "$SCRIPT_NAME" "Java home already correctly set in ${conf_file}." "INFO"
        else
            log_message "$SCRIPT_NAME" "Java home directive in ${conf_file} is incorrect. Updating..." "WARN"
            if [ "$need_sudo" = "true" ]; then
                sudo cp "${conf_file}" "${conf_file}.bak"
                sudo sed -i.bak "s|^SetJavaHome.*|SetJavaHome ${JAVA_HOME_PATH}|" "${conf_file}"
            else
                cp "${conf_file}" "${conf_file}.bak"
                sed -i.bak "s|^SetJavaHome.*|SetJavaHome ${JAVA_HOME_PATH}|" "${conf_file}"
            fi
            log_message "$SCRIPT_NAME" "Updated JavaHome in ${conf_file}. Backup created: ${conf_file}.bak" "INFO"
        fi
    else
        log_message "$SCRIPT_NAME" "SetJavaHome directive not found in ${conf_file}. Adding it." "INFO"
        if [ "$need_sudo" = "true" ]; then
            echo "SetJavaHome ${JAVA_HOME_PATH}" | sudo tee -a "${conf_file}" > /dev/null
        else
            echo "SetJavaHome ${JAVA_HOME_PATH}" >> "${conf_file}"
        fi
        log_message "$SCRIPT_NAME" "Added JavaHome to ${conf_file}." "INFO"
    fi
    return 0
}

# 1. Update user-specific product.conf (primary target)
#    e.g. sqldeveloper-21.4.3-063.0100.noarch.rpm -> 21.4.3
SQLDEV_VERSION_SHORT=$(echo "${SQLDEV_RPM_NAME}" | sed -n 's/sqldeveloper-\([0-9.]\+\)-.*/\1/p')
if [ -z "${SQLDEV_VERSION_SHORT}" ]; then
    log_message "$SCRIPT_NAME" "Could not reliably parse SQL Developer short version from RPM name: ${SQLDEV_RPM_NAME}. Cannot update user product.conf." "WARN"
else
    SQLDEV_PRODUCT_CONF_USER="${HOME}/.sqldeveloper/${SQLDEV_VERSION_SHORT}/product.conf"
    log_message "$SCRIPT_NAME" "Targeting user-specific SQL Developer config: ${SQLDEV_PRODUCT_CONF_USER}" "INFO"
    # Ensure the directory exists, creating as the current user (not sudo initially)
    # The update_set_java_home function will use sudo -u for file operations if needed.
    mkdir -p "$(dirname "${SQLDEV_PRODUCT_CONF_USER}")"
    # Create an empty file if it doesn't exist so stat can get owner, or touch to update timestamp
    touch "${SQLDEV_PRODUCT_CONF_USER}" 
    update_set_java_home "${SQLDEV_PRODUCT_CONF_USER}"
fi

# 2. Update system-wide sqldeveloper.conf (fallback/secondary)
# Try to locate via RPM contents, then fall back to search
SQLDEV_CONF_SYSTEM="$(rpm -ql "${SQLDEV_PACKAGE_NAME}" 2>/dev/null | grep '/sqldeveloper/bin/sqldeveloper\.conf$' | head -n1 || true)"
if [ -z "$SQLDEV_CONF_SYSTEM" ]; then
    SQLDEV_CONF_SYSTEM="$(find /opt /usr -xdev -path '*/sqldeveloper/bin/sqldeveloper.conf' -type f 2>/dev/null | head -n1 || true)"
fi
if [ -n "$SQLDEV_CONF_SYSTEM" ] && [ -f "$SQLDEV_CONF_SYSTEM" ]; then
    update_set_java_home "${SQLDEV_CONF_SYSTEM}"
else
    log_message "$SCRIPT_NAME" "SQL Developer system config file not found via RPM or search. Skipping system config update." "INFO"
fi

# Attempt to install canberra-gtk-module to reduce GTK errors
if command -v yum &> /dev/null; then
    if ! rpm -q libcanberra-gtk2 &> /dev/null && ! rpm -q libcanberra-gtk3 &> /dev/null; then
        log_message "$SCRIPT_NAME" "Attempting to install libcanberra-gtk-module (yum)..." "INFO"
        sudo yum install -y libcanberra-gtk2 libcanberra-gtk3 >> "$LOG_FILE" 2>&1 || log_message "$SCRIPT_NAME" "Failed to install libcanberra-gtk-modules via yum. This might be okay." "WARN"
    fi
elif command -v apt-get &> /dev/null; then
    if ! dpkg -s libcanberra-gtk-module &> /dev/null && ! dpkg -s libcanberra-gtk3-module &> /dev/null; then
        log_message "$SCRIPT_NAME" "Attempting to install libcanberra-gtk-module (apt)..." "INFO"
        sudo apt-get update >> "$LOG_FILE" 2>&1
        sudo apt-get install -y libcanberra-gtk-module libcanberra-gtk3-module >> "$LOG_FILE" 2>&1 || log_message "$SCRIPT_NAME" "Failed to install libcanberra-gtk-modules via apt. This might be okay." "WARN"
    fi
fi

log_message "$SCRIPT_NAME" "SQL Developer installation and Java configuration process completed." "INFO"
exit 0