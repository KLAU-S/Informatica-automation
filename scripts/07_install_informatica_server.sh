#!/bin/bash

# 07_install_informatica_server.sh
# Silent installation of Informatica PowerCenter Server 9.5.1HF2

source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="07_install_infa_server"
log_message "$SCRIPT_NAME" "Starting Informatica Server 9.5.1HF2 installation process." "INFO"

# Check if Informatica is already installed
if [ -d "${INFA_HOME}" ] && [ -f "${INFA_HOME}/tomcat/bin/infaservice.sh" ]; then
    log_message "$SCRIPT_NAME" "Informatica Server already installed at ${INFA_HOME}. Checking if services are responsive..." "INFO"
    
    # Quick check if infacmd.sh exists and domain is responsive
    if [ -f "${INFA_HOME}/isp/bin/infacmd.sh" ]; then
        # Try a quick domain ping - this will fail if domain is not configured but won't hurt
        if "${INFA_HOME}/isp/bin/infacmd.sh" ping -dn "${INFA_DOMAIN_NAME}" -un "${INFA_ADMIN_USER}" -pd "${INFA_ADMIN_PASS}" >/dev/null 2>&1; then
            log_message "$SCRIPT_NAME" "Informatica Server installation and domain configuration appears complete. Skipping installation." "INFO"
            exit 0
        else
            log_message "$SCRIPT_NAME" "Informatica Server installed but domain may not be configured. Continuing with configuration check..." "INFO"
        fi
    else
        log_message "$SCRIPT_NAME" "Informatica installation found but infacmd.sh missing. May need reinstallation." "WARN"
    fi
else
    log_message "$SCRIPT_NAME" "Informatica Server not found at ${INFA_HOME}. Proceeding with installation." "INFO"
fi

# Check if domain is already configured (skip installation if so)
if [ -f "${INFA_HOME}/isp/bin/infacmd.sh" ]; then
    log_message "$SCRIPT_NAME" "infacmd.sh found. Testing domain responsiveness..." "INFO"
    if "${INFA_HOME}/isp/bin/infacmd.sh" ping -dn "${INFA_DOMAIN_NAME}" -un "${INFA_ADMIN_USER}" -pd "${INFA_ADMIN_PASS}" >/dev/null 2>&1; then
        log_message "$SCRIPT_NAME" "Domain ${INFA_DOMAIN_NAME} is responsive. Installation appears complete." "INFO"
        exit 0
    fi
else
    log_message "$SCRIPT_NAME" "Informatica not installed or infacmd.sh not available for domain responsiveness check." "INFO"
fi

log_message "$SCRIPT_NAME" "Installing Informatica Server." "INFO"

# Check for Oracle profile/environment
if [ -f /home/oracle/.bash_profile ]; then
    log_message "$SCRIPT_NAME" "Oracle profile found." "INFO"
else
    log_message "$SCRIPT_NAME" "Oracle profile not found." "WARN"
fi

# Ensure hostname mapping for INFA_NODE_HOST to the primary VM IP to avoid domain ping failures
ensure_hosts_mapping() {
    local desired_host="${INFA_NODE_HOST}"
    if [ -z "$desired_host" ]; then
        return 0
    fi
    # Determine primary IPv4 address (non-loopback)
    local primary_ip
    primary_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')
    if [ -z "$primary_ip" ]; then
        primary_ip=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i!~/^127\./){print $i; exit}}}')
    fi
    if [ -z "$primary_ip" ]; then
        log_message "$SCRIPT_NAME" "Could not determine primary IP for hosts mapping. Skipping /etc/hosts update." "WARN"
        return 0
    fi
    # Check existing mapping
    local current_map
    current_map=$(grep -E "\s${desired_host}(\s|$)" /etc/hosts 2>/dev/null | tail -n1 || true)
    if [ -n "$current_map" ]; then
        # If mapped to 127.* or wrong IP, replace it
        if echo "$current_map" | grep -qE "^127\.|^::1|^0\.0\.0\.0" || ! echo "$current_map" | grep -q "^$primary_ip\b"; then
            log_message "$SCRIPT_NAME" "Updating /etc/hosts mapping for ${desired_host} -> ${primary_ip}" "INFO"
            sudo sed -r -i "/(^|[[:space:]])${desired_host}([[:space:]]|$)/d" /etc/hosts
            echo "$primary_ip ${desired_host}" | sudo tee -a /etc/hosts >/dev/null
        else
            log_message "$SCRIPT_NAME" "/etc/hosts already maps ${desired_host} to ${primary_ip}" "INFO"
        fi
    else
        log_message "$SCRIPT_NAME" "Adding /etc/hosts mapping for ${desired_host} -> ${primary_ip}" "INFO"
        echo "$primary_ip ${desired_host}" | sudo tee -a /etc/hosts >/dev/null
    fi
}

ensure_hosts_mapping

# Optionally relax firewall to allow domain/admin ports during install
relax_firewall() {
    if command -v firewall-cmd >/dev/null 2>&1; then
        if sudo firewall-cmd --state >/dev/null 2>&1; then
            log_message "$SCRIPT_NAME" "Temporarily opening Informatica ports in firewalld (6005-6010, 6008)." "INFO"
            sudo firewall-cmd --add-port=6005-6010/tcp --permanent >/dev/null 2>&1 || true
            sudo firewall-cmd --add-port=6008/tcp --permanent >/dev/null 2>&1 || true
            sudo firewall-cmd --reload >/dev/null 2>&1 || true
        fi
    fi
}

relax_firewall

# Prepare the response file for silent installation
RESPONSE_FILE="${INFA_RESPONSE_FILES_DIR}/SilentInput.properties"
log_message "$SCRIPT_NAME" "Generating ${RESPONSE_FILE}..." "INFO"

mkdir -p "${INFA_RESPONSE_FILES_DIR}"

# Generate the SilentInput.properties file
cat > "${RESPONSE_FILE}" << EOF
# Informatica PowerCenter 9.5.1HF2 Silent Installation Response File
# Generated by automated installation script

# License acceptance
LICENSE_KEY_LOC=${DOWNLOAD_DIR}/informatica/${INFA_LICENSE_KEY_NAME}
ACCEPT_EULA=Y

# Installation Type (1 for new install)
SELECTED_INSTALLATION_TYPE=1

# Installation directory
USER_INSTALL_DIR=${INFA_HOME}

# Enable silent mode
ENABLE_USAGE_COLLECTION=0
INSTALLER_UI=silent

# Database connection details for DOMAIN repository
DATABASE_TYPE=Oracle
DATABASE_HOST=${INFA_DOMAIN_DB_HOST}       # From 00_config.sh
DATABASE_PORT=${INFA_DOMAIN_DB_PORT}       # From 00_config.sh
DATABASE_SERVICENAME=${INFA_DOMAIN_DB_SERVICE_NAME} # From 00_config.sh
DATABASE_USERNAME=${INFA_DOM_USER}         # From 00_config.sh
DATABASE_PASSWORD=${INFA_DOM_PASS}         # From 00_config.sh

# Domain configuration
DOMAIN_NAME=${INFA_DOMAIN_NAME}
DOMAIN_HOST=${INFA_NODE_HOST}          # Using INFA_NODE_HOST from 00_config.sh
DOMAIN_PORT=6005                     # Default port observed

# Domain administrator
DOMAIN_USER=${INFA_ADMIN_USER}
DOMAIN_PASSWORD=${INFA_ADMIN_PASS}

# Node configuration
NODE_NAME=${INFA_NODE_NAME}
NODE_HOST=${INFA_NODE_HOST}            # From 00_config.sh
NODE_PORT=6005                       # Default port observed

# Security domain (typically Native)
SECURITY_DOMAIN=Native

# Create Domain and Configure it
CREATE_DOMAIN=1
CONFIGURE_DOMAIN=1

# Skip Pre-installation System Check Tool (i9Pi)
SKIP_PREINSTALL_CHECK=Y

# Additional silent installation parameters
SELECTED_INSTALLATION_FEATURE_LIST=all
CHOSEN_INSTALL_FEATURE_LIST=server,client
CHOSEN_FEATURE_LIST=server,client

# Accept license agreement
LICENSE_ACCEPTED=true

# Force silent mode parameters
IS_SILENT_INSTALL=true
SILENT_INSTALL=true

EOF

log_message "$SCRIPT_NAME" "Generated ${RESPONSE_FILE}." "INFO"

# Ensure the response file path is available to the Expect script via environment
export RESPONSE_FILE

# Verify installer directory and files
SERVER_INSTALLER_DIR="${TEMP_INSTALL_DIR}/informatica_server_installer_payload"
if [ ! -d "$SERVER_INSTALLER_DIR" ] || [ ! -f "${SERVER_INSTALLER_DIR}/install.sh" ]; then
    log_message "$SCRIPT_NAME" "Informatica server installer not found at ${SERVER_INSTALLER_DIR}/install.sh" "ERROR"
    log_message "$SCRIPT_NAME" "Please run 06_prepare_informatica_installers.sh first." "ERROR"
    exit 1
fi

# Verify license key exists
if [ ! -f "${DOWNLOAD_DIR}/informatica/${INFA_LICENSE_KEY_NAME}" ]; then
    log_message "$SCRIPT_NAME" "License key not found at ${DOWNLOAD_DIR}/informatica/${INFA_LICENSE_KEY_NAME}" "ERROR"
    log_message "$SCRIPT_NAME" "Please run 06_prepare_informatica_installers.sh to extract the license key." "ERROR"
    exit 1
fi

log_message "$SCRIPT_NAME" "Running Informatica Server installation from ${SERVER_INSTALLER_DIR}..." "INFO"

# Change to installer directory
cd "${SERVER_INSTALLER_DIR}" || {
    log_message "$SCRIPT_NAME" "Failed to change to installer directory ${SERVER_INSTALLER_DIR}" "ERROR"
    exit 1
}

# Save current environment variables that might interfere with installation
SAVED_INFA_HOME="${INFA_HOME}"
SAVED_INFA_NODE_NAME="${INFA_NODE_NAME}"
SAVED_INFA_DOMAINS_FILE="${INFA_DOMAINS_FILE}"

log_message "$SCRIPT_NAME" "Temporarily unsetting Informatica environment variables for installation..." "INFO"

# Provide EXPECT-specific environment variables for the expect script to avoid relying on unset INFA_* vars
export EXPECT_DB_HOST="${INFA_DOMAIN_DB_HOST}"
export EXPECT_DB_PORT="${INFA_DOMAIN_DB_PORT}"
export EXPECT_DB_SERVICE="${INFA_DOMAIN_DB_SERVICE_NAME}"
export EXPECT_DOMAIN_NAME="${INFA_DOMAIN_NAME}"
export EXPECT_NODE_HOST="${INFA_NODE_HOST}"
export EXPECT_NODE_NAME="${INFA_NODE_NAME}"
export EXPECT_ADMIN_USER="${INFA_ADMIN_USER}"
export EXPECT_ADMIN_PASS="${INFA_ADMIN_PASS}"

# Unset environment variables that interfere with installation (keep EXPECT_* above)
unset INFA_HOME
unset INFA_NODE_NAME  
unset INFA_DOMAINS_FILE
unset INFORMATICA_HOME

# Check available disk space first
AVAILABLE_SPACE=$(df -BG "${SAVED_INFA_HOME%/*}" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
if [ -n "$AVAILABLE_SPACE" ] && [ "$AVAILABLE_SPACE" -lt 10 ]; then
    log_message "$SCRIPT_NAME" "Warning: Less than 10GB available space. Informatica requires significant disk space." "WARN"
fi

# Create the installation directory with proper permissions beforehand
log_message "$SCRIPT_NAME" "Pre-creating installation directory: ${SAVED_INFA_HOME}" "INFO"
sudo mkdir -p "${SAVED_INFA_HOME}" 2>/dev/null || mkdir -p "${SAVED_INFA_HOME}" 2>/dev/null
sudo chown -R ${USER}:${USER} "${SAVED_INFA_HOME%/*}" 2>/dev/null || true

log_message "$SCRIPT_NAME" "Starting automated installation (this may take a while)..." "INFO"

EXPECT_SCRIPT="${TEMP_INSTALL_DIR}/install_comprehensive.exp"

# Ensure installer script is executable
if [ ! -x "./install.sh" ]; then
    chmod +x ./install.sh 2>/dev/null || true
fi

cat > "${EXPECT_SCRIPT}" <<'EXPECT_EOF'
#!/usr/bin/expect -f
set timeout 7200
# Arguments:
# argv 0: install_dir
# argv 1: license_key_path
# argv 2: db_user (for pre-check and domain config)
# argv 3: db_password (for pre-check and domain config)

set install_dir      [lindex $argv 0]
set license_key_path [lindex $argv 1]
set db_user          [lindex $argv 2]
set db_password      [lindex $argv 3]

    # Read needed values from environment to avoid shell interpolation issues
    set response_file    $env(RESPONSE_FILE)
    set db_host          $env(EXPECT_DB_HOST)
    set db_port          $env(EXPECT_DB_PORT)
    set db_service       $env(EXPECT_DB_SERVICE)
    set domain_name      $env(EXPECT_DOMAIN_NAME)
    set node_host        $env(EXPECT_NODE_HOST)
    set node_name        $env(EXPECT_NODE_NAME)
    set admin_user       $env(EXPECT_ADMIN_USER)
    set admin_pass       $env(EXPECT_ADMIN_PASS)

# Enable logging
log_user 1

    # Run the interactive console installer (not silent) and drive it with expect to match actual prompts
    spawn env -u INFA_HOME -u INFA_NODE_NAME -u INFA_DOMAINS_FILE -u INFORMATICA_HOME ./install.sh

expect {
    # Early continuation prompt observed before main menu
    -re {Do you want to continue installation \(y/n\)\s*\?} {
        send "y\r"
        exp_continue
    }
    -re {Do you want to continue\?? \(Y/N\)} {
        send "Y\r"
        exp_continue
    }
    "Do you want to continue? (Y/N)" {
        send "Y\r"
        exp_continue
    }
    # Initial: 1. Install or upgrade Informatica... 2. DTE Only... 3. Apply Hotfix...
    "Enter the choice(1, 2 or 3):" {
        send "1\r"
        exp_continue
    }
    "Do you want to run the Pre-Installation System Check Tool (i9Pi) before you start the installation process (y/n)?" {
        send "n\r"
        exp_continue
    }
    "Do you want to continue the Informatica Server Installation (y/n) ?" {
        send "y\r"
        exp_continue
    }
    # General "Press Enter" prompt, used multiple times
    "Press <Enter> to continue ..." {
        send "\r"
        exp_continue
    }
    # (Skipping i9Pi pre-installation system check entirely; we answered 'n' above)
    # After pre-check summary, directly to GUI/Console mode
    "Select (G)UI mode (needs X Window support) or (C)onsole mode (G/C):" {
        send "C\r"
        exp_continue
    }

    # Main Installation Steps
    # Installation Type - Step 1 of 7
    "*Select to install or upgrade*:" {
        send "1\r"
        exp_continue
    }
    # Installation Pre-Requisites - Step 2 of 7 (Handled by "Press <Enter> to continue ...")

    # License Key - Step 3 of 7
    "Enter the license key file (default :- *) :" {
        send "$license_key_path\r"
        exp_continue
    }
    # Installation Directory - Step 3 of 7 (this is a second prompt for install dir)
    "Enter the installation directory (default :- *) :" {
        send "$install_dir\r"
        exp_continue
    }
    # Pre-Installation Summary - Step 4 of 7 (Handled by "Press <Enter> to continue ...")

    # Installing - Step 5 of 7 (Progress bar, no input needed)

    # Domain Selection - Step 5A of 7
    "*1->Create a domain*" {
        send "1\r"
        exp_continue
    }
    "*Enable Transport Layer Security*" {
        send "1\r"
        exp_continue
    }
    "*Enable HTTPS for Informatica Administrator*" {
        send "2\r"
        exp_continue
    }
    "Port: (default :- 8443) :" {
        send "\r"
        exp_continue
    }
    "*Use a keystore file generated by the installer*" {
        send "1\r"
        exp_continue
    }

    # Domain Configuration Repository - Step 5B of 7
    "*Database type*:" {
        send "1\r"
        exp_continue
    }
    "Database user ID:*" {
        send "$db_user\r"
        exp_continue
    }
    "*User password*" {
        send "$db_password\r"
        exp_continue
    }
    "*Configure the database connection*" {
        send "1\r"
        exp_continue
    }
    "Database address: (default :- *) :" {
        send "$db_host:$db_port\r"
        exp_continue
    }
    "Database service name: (default :- *) :" {
        send "$db_service\r"
        exp_continue
    }
    "*Configure JDBC parameters*" {
        send "2\r"
        exp_continue
    }

    # Domain and Node Configuration - Step 6 of 7
    "Domain name: (default :- *) :" {
        send "$domain_name\r"
        exp_continue
    }
    "Node host name: (default :- *) :" {
        send "$node_host\r"
        exp_continue
    }
    "Node name: (default :- *) :" {
        send "$node_name\r"
        exp_continue
    }
    "Node port number: (default :- *) :" {
        send "\r"
        exp_continue
    }
    "Domain user name: (default :- *) :" {
        send "$admin_user\r"
        exp_continue
    }
    "Domain password: (default :- *) :" {
        send "$admin_pass\r"
        exp_continue
    }
    "Confirm password: (default :- *) :" {
        send "$admin_pass\r"
        exp_continue
    }
    "*Display advanced port configuration page*" {
        send "1\r"
        exp_continue
    }

    "Installation Complete" {
        send "\r"
        exp_continue
    }
    "Press <Enter> to exit the installer" {
        send "\r"
    }
    "Press Enter to exit the installer" {
        send "\r"
    }
    eof {
        catch wait result
        exit [lindex $result 3]
    }
    timeout {
        puts "Installation timed out after 2 hours"
        exit 1
    }
}
EXPECT_EOF

chmod +x "${EXPECT_SCRIPT}"

# Run the installation using expect
if command -v expect >/dev/null 2>&1; then
    log_message "$SCRIPT_NAME" "Running comprehensive automated installation with expect..." "INFO"
    
    # Pass only 4 arguments: install_dir, license_key_path, db_user, db_password
    # Other values are embedded from 00_config.sh into the EXPECT_SCRIPT above
    if "${EXPECT_SCRIPT}" \
        "${SAVED_INFA_HOME}" \
        "${DOWNLOAD_DIR}/informatica/${INFA_LICENSE_KEY_NAME}" \
        "${INFA_DOM_USER}" \
        "${INFA_DOM_PASS}" \
        2>&1 | tee "${TEMP_INSTALL_DIR}/install_comprehensive_output.log"; then
        INSTALL_SUCCESS=true
        log_message "$SCRIPT_NAME" "Expect script finished. Checking installation status from logs/exit codes." "INFO"
    else
        INSTALL_EXIT_CODE=$?
        log_message "$SCRIPT_NAME" "Expect script execution failed or installer returned error. Exit code: ${INSTALL_EXIT_CODE}" "ERROR"
        INSTALL_SUCCESS=false
        # Dump tail of installer output for debugging
        if [ -f "${TEMP_INSTALL_DIR}/install_comprehensive_output.log" ]; then
            log_message "$SCRIPT_NAME" "Installer output (last 200 lines):" "ERROR"
            tail -200 "${TEMP_INSTALL_DIR}/install_comprehensive_output.log" >> "$LOG_FILE"
        fi
    fi
else
    log_message "$SCRIPT_NAME" "expect command not available. Cannot proceed with automated installation." "ERROR"
    log_message "$SCRIPT_NAME" "Please install expect package: sudo yum install expect -y" "ERROR"
    exit 1
fi
chmod +x "${EXPECT_SCRIPT}"

# Clean up temporary files
rm -f "${EXPECT_SCRIPT}" 2>/dev/null

# Skip heuristic override; rely on exit code and file verification below

# If installation failed, show output and exit
if [ "$INSTALL_SUCCESS" != "true" ]; then
    log_message "$SCRIPT_NAME" "Installation failed or did not complete as expected. Showing output..." "ERROR"
    # Also print last lines if not already printed
    if [ -f "${TEMP_INSTALL_DIR}/install_comprehensive_output.log" ]; then
        log_message "$SCRIPT_NAME" "Installer output (last 200 lines):" "ERROR"
        tail -200 "${TEMP_INSTALL_DIR}/install_comprehensive_output.log" >> "$LOG_FILE"
    fi
    exit 1
fi

# Restore environment variables after installation
log_message "$SCRIPT_NAME" "Restoring Informatica environment variables..." "INFO"
export INFA_HOME="${SAVED_INFA_HOME}"
export INFA_NODE_NAME="${SAVED_INFA_NODE_NAME}"
if [ -n "${SAVED_INFA_DOMAINS_FILE}" ]; then
    export INFA_DOMAINS_FILE="${SAVED_INFA_DOMAINS_FILE}"
fi

# Verify installation success
log_message "$SCRIPT_NAME" "Verifying Informatica Server installation..." "INFO"

# Check for common Informatica installation directories
POSSIBLE_INSTALL_DIRS=(
    "${INFA_HOME}"
    "/opt/Informatica"
    "/opt/informatica"
    "${HOME}/Informatica"
    "/usr/local/Informatica"
)

ACTUAL_INSTALL_DIR=""
for dir in "${POSSIBLE_INSTALL_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        log_message "$SCRIPT_NAME" "Found Informatica installation at: $dir" "INFO"
        if [ -f "$dir"/*/tomcat/bin/infaservice.sh ] || [ -f "$dir/tomcat/bin/infaservice.sh" ]; then
            ACTUAL_INSTALL_DIR="$dir"
            break
        fi
    fi
done

if [ -z "$ACTUAL_INSTALL_DIR" ]; then
    log_message "$SCRIPT_NAME" "Installation failed - Informatica directory not found in expected locations." "ERROR"
    log_message "$SCRIPT_NAME" "Checking installation output for clues..." "ERROR"
    
    # Show installation output
    if [ -f "${TEMP_INSTALL_DIR}/install_comprehensive_output.log" ]; then
        log_message "$SCRIPT_NAME" "Installation output (last 100 lines):" "ERROR"
        tail -100 "${TEMP_INSTALL_DIR}/install_comprehensive_output.log" >> "$LOG_FILE"
    fi
    
    # Check if installer created any directories
    log_message "$SCRIPT_NAME" "Searching for any Informatica installations..." "INFO"
    find /opt /usr/local "${HOME}" -maxdepth 3 -name "*nformatica*" -type d 2>/dev/null | head -10 >> "$LOG_FILE" || true
    find /opt /usr/local "${HOME}" -maxdepth 3 -name "*infaservice.sh" -type f 2>/dev/null | head -5 >> "$LOG_FILE" || true
    
    exit 1
fi

# Update INFA_HOME if installation was found elsewhere
if [ "$ACTUAL_INSTALL_DIR" != "${SAVED_INFA_HOME}" ]; then
    log_message "$SCRIPT_NAME" "Informatica installed at $ACTUAL_INSTALL_DIR instead of expected ${SAVED_INFA_HOME}" "INFO"
    
    # Find the actual version directory
    if [ -d "$ACTUAL_INSTALL_DIR" ] && [ ! -f "$ACTUAL_INSTALL_DIR/tomcat/bin/infaservice.sh" ]; then
        # Look for version subdirectories
        for version_dir in "$ACTUAL_INSTALL_DIR"/*; do
            if [ -d "$version_dir" ] && [ -f "$version_dir/tomcat/bin/infaservice.sh" ]; then
                ACTUAL_INSTALL_DIR="$version_dir"
                break
            fi
        done
    fi
    
    INFA_HOME="$ACTUAL_INSTALL_DIR"
    log_message "$SCRIPT_NAME" "Updated INFA_HOME to: ${INFA_HOME}" "INFO"
fi

if [ ! -d "${INFA_HOME}" ]; then
    log_message "$SCRIPT_NAME" "Installation failed - ${INFA_HOME} directory not created." "ERROR"
    exit 1
fi

if [ ! -f "${INFA_HOME}/tomcat/bin/infaservice.sh" ]; then
    log_message "$SCRIPT_NAME" "Installation may be incomplete - infaservice.sh not found at ${INFA_HOME}/tomcat/bin/" "ERROR"
    log_message "$SCRIPT_NAME" "Contents of ${INFA_HOME}:" "INFO"
    ls -la "${INFA_HOME}" >> "$LOG_FILE"
    
    if [ -d "${INFA_HOME}/tomcat" ]; then
        log_message "$SCRIPT_NAME" "Contents of ${INFA_HOME}/tomcat:" "INFO"
        ls -la "${INFA_HOME}/tomcat" >> "$LOG_FILE"
        
        if [ -d "${INFA_HOME}/tomcat/bin" ]; then
            log_message "$SCRIPT_NAME" "Contents of ${INFA_HOME}/tomcat/bin:" "INFO"
            ls -la "${INFA_HOME}/tomcat/bin" >> "$LOG_FILE"
        fi
    fi
    exit 1
fi

if [ ! -f "${INFA_HOME}/isp/bin/infacmd.sh" ]; then
    log_message "$SCRIPT_NAME" "Installation may be incomplete - infacmd.sh not found at ${INFA_HOME}/isp/bin/" "ERROR"
    log_message "$SCRIPT_NAME" "Contents of ${INFA_HOME}/isp:" "INFO"
    if [ -d "${INFA_HOME}/isp" ]; then
        ls -la "${INFA_HOME}/isp" >> "$LOG_FILE"
        if [ -d "${INFA_HOME}/isp/bin" ]; then
            log_message "$SCRIPT_NAME" "Contents of ${INFA_HOME}/isp/bin:" "INFO"
            ls -la "${INFA_HOME}/isp/bin" >> "$LOG_FILE"
        fi
    fi
    exit 1
fi

log_message "$SCRIPT_NAME" "Informatica Server installation verified successfully." "INFO"

# Set proper permissions
log_message "$SCRIPT_NAME" "Setting proper permissions on Informatica installation..." "INFO"
if ! exec_cmd "$SCRIPT_NAME" "sudo chown -R ${USER}:${USER} \"${INFA_HOME}\"" \
    "Permissions set successfully." \
    "Failed to set permissions on Informatica installation."; then
    log_message "$SCRIPT_NAME" "Permission setting failed, but installation may still work." "WARN"
fi

# Make key scripts executable
chmod +x "${INFA_HOME}/tomcat/bin/infaservice.sh" 2>/dev/null
chmod +x "${INFA_HOME}/isp/bin/infacmd.sh" 2>/dev/null

log_message "$SCRIPT_NAME" "Informatica Server 9.5.1HF2 installation completed successfully." "INFO"
log_message "$SCRIPT_NAME" "Installation location: ${INFA_HOME}" "INFO"
exit 0