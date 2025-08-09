#!/bin/bash

# 02_install_jdk.sh
# Installs Zulu JDK 8 with JavaFX support.

source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="02_install_jdk"
log_message "$SCRIPT_NAME" "Starting JDK 8 (Zulu with JavaFX) installation process." "INFO"

jdk_configured=false
if [ -d "${JAVA_HOME_PATH}" ] && [ -x "${JAVA_HOME_PATH}/bin/java" ]; then
    current_java_version=$("${JAVA_HOME_PATH}/bin/java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    if [[ "$current_java_version" == *"1.8.0_392"* ]]; then
        log_message "$SCRIPT_NAME" "JDK 8u392 (Zulu with JavaFX) seems to be already installed at ${JAVA_HOME_PATH}." "INFO"
        jdk_configured=true
    else
        log_message "$SCRIPT_NAME" "A Java installation exists at ${JAVA_HOME_PATH}, but it's not 1.8.0_392 (found ${current_java_version}). Proceeding with installation." "WARN"
    fi
else
    log_message "$SCRIPT_NAME" "JDK not found at ${JAVA_HOME_PATH}. Proceeding with installation." "INFO"
fi

if $jdk_configured; then
    log_message "$SCRIPT_NAME" "JDK 8u392 (Zulu with JavaFX) already configured. Ensuring profile script exists." "INFO"
else
    log_message "$SCRIPT_NAME" "Installing JDK 8u392 (Zulu with JavaFX)." "INFO"
    JDK_ARCHIVE_PATH="${DOWNLOAD_DIR}/jdk/${JDK_ARCHIVE_NAME}"
    if [ ! -f "$JDK_ARCHIVE_PATH" ]; then
        log_message "$SCRIPT_NAME" "JDK archive ${JDK_ARCHIVE_PATH} not found. Please run download script or place it manually." "ERROR"
        exit 1
    fi

    if ! exec_cmd "$SCRIPT_NAME" "sudo mkdir -p ${JDK_INSTALL_DIR}" \
        "Created JDK installation directory ${JDK_INSTALL_DIR}." \
        "Failed to create JDK installation directory ${JDK_INSTALL_DIR}."; then
        exit 1
    fi

    log_message "$SCRIPT_NAME" "Extracting JDK to ${JDK_INSTALL_DIR}..." "INFO"
    if ! exec_cmd "$SCRIPT_NAME" "sudo tar xzf \"${JDK_ARCHIVE_PATH}\" -C \"${JDK_INSTALL_DIR}\"" \
        "Successfully extracted JDK." \
        "Failed to extract JDK."; then
        exit 1
    fi

    # Find the actual extracted directory name
    EXTRACTED_DIR=$(sudo find "${JDK_INSTALL_DIR}" -maxdepth 1 -type d -name "*zulu*jdk*" | head -1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        log_message "$SCRIPT_NAME" "Could not find extracted Zulu JDK directory in ${JDK_INSTALL_DIR}." "ERROR"
        exit 1
    fi
    
    EXTRACTED_DIR_NAME=$(basename "$EXTRACTED_DIR")
    log_message "$SCRIPT_NAME" "Found extracted JDK directory: ${EXTRACTED_DIR_NAME}" "INFO"
    
    # If the extracted directory name doesn't match our expected name, create a symlink
    if [ "$EXTRACTED_DIR_NAME" != "$JDK_VERSION_NAME" ]; then
        log_message "$SCRIPT_NAME" "Extracted directory name (${EXTRACTED_DIR_NAME}) differs from expected (${JDK_VERSION_NAME}). Creating symlink." "WARN"
        
        # Remove existing symlink or directory if it exists
        if [ -L "${JAVA_HOME_PATH}" ] || [ -d "${JAVA_HOME_PATH}" ]; then
            sudo rm -rf "${JAVA_HOME_PATH}"
        fi
        
        # Create symlink
        if ! sudo ln -s "${EXTRACTED_DIR}" "${JAVA_HOME_PATH}"; then
            log_message "$SCRIPT_NAME" "Failed to create symlink from ${EXTRACTED_DIR} to ${JAVA_HOME_PATH}." "ERROR"
            exit 1
        fi
        log_message "$SCRIPT_NAME" "Created symlink: ${JAVA_HOME_PATH} -> ${EXTRACTED_DIR}" "INFO"
    fi

    # Verify the JDK is accessible
    if [ ! -d "${JAVA_HOME_PATH}" ] || [ ! -x "${JAVA_HOME_PATH}/bin/java" ]; then
        log_message "$SCRIPT_NAME" "JDK installation verification failed. ${JAVA_HOME_PATH}/bin/java not found or not executable." "ERROR"
        exit 1
    fi
    log_message "$SCRIPT_NAME" "JDK successfully installed and accessible at ${JAVA_HOME_PATH}." "INFO"
    
    # Verify JavaFX is included
    if [ -d "${JAVA_HOME_PATH}/lib" ] && find "${JAVA_HOME_PATH}/lib" -name "*javafx*" -o -name "*jfx*" | grep -q .; then
        log_message "$SCRIPT_NAME" "JavaFX libraries detected in JDK installation." "INFO"
    else
        log_message "$SCRIPT_NAME" "WARNING: JavaFX libraries not detected. This may cause issues with Informatica GUI components." "WARN"
    fi
fi

PROFILE_SCRIPT_JDK="/etc/profile.d/jdk.sh"
log_message "$SCRIPT_NAME" "Configuring JDK environment variables in ${PROFILE_SCRIPT_JDK}..." "INFO"
JDK_PROFILE_CONTENT=$(cat <<EOF
export JAVA_HOME=${JAVA_HOME_PATH}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
)

# Create profile script only if it doesn't exist or content differs
current_profile_content=""
if [ -f "${PROFILE_SCRIPT_JDK}" ]; then
    current_profile_content=$(sudo cat "${PROFILE_SCRIPT_JDK}")
fi

if [ "${current_profile_content}" != "${JDK_PROFILE_CONTENT}" ]; then
    if ! echo "${JDK_PROFILE_CONTENT}" | sudo tee "${PROFILE_SCRIPT_JDK}" > /dev/null; then
        log_message "$SCRIPT_NAME" "Failed to write JDK profile script to ${PROFILE_SCRIPT_JDK}." "ERROR"
        exit 1
    fi
    sudo chmod +x "${PROFILE_SCRIPT_JDK}"
    log_message "$SCRIPT_NAME" "JDK profile script created/updated at ${PROFILE_SCRIPT_JDK}." "INFO"
else
    log_message "$SCRIPT_NAME" "JDK profile script ${PROFILE_SCRIPT_JDK} already up-to-date." "INFO"
fi
log_message "$SCRIPT_NAME" "Please source this script or log out/in for changes to take effect: source ${PROFILE_SCRIPT_JDK}" "INFO"

if command -v update-alternatives &> /dev/null; then
    log_message "$SCRIPT_NAME" "Configuring Java alternatives..." "INFO"
    
    # Remove any existing alternatives for this Java version first
    existing_java_alt=$(update-alternatives --display java 2>/dev/null | grep "${JAVA_HOME_PATH}/bin/java" || true)
    existing_javac_alt=$(update-alternatives --display javac 2>/dev/null | grep "${JAVA_HOME_PATH}/bin/javac" || true)
    
    if [ -n "$existing_java_alt" ]; then
        sudo update-alternatives --remove java "${JAVA_HOME_PATH}/bin/java" 2>/dev/null || true
        log_message "$SCRIPT_NAME" "Removed existing java alternative." "INFO"
    fi
    
    if [ -n "$existing_javac_alt" ]; then
        sudo update-alternatives --remove javac "${JAVA_HOME_PATH}/bin/javac" 2>/dev/null || true
        log_message "$SCRIPT_NAME" "Removed existing javac alternative." "INFO"
    fi
    
    # Install and set new alternatives
    sudo update-alternatives --install /usr/bin/java java "${JAVA_HOME_PATH}/bin/java" 180392
    sudo update-alternatives --set java "${JAVA_HOME_PATH}/bin/java"
    log_message "$SCRIPT_NAME" "Java alternative installed and set." "INFO"
    
    sudo update-alternatives --install /usr/bin/javac javac "${JAVA_HOME_PATH}/bin/javac" 180392
    sudo update-alternatives --set javac "${JAVA_HOME_PATH}/bin/javac"
    log_message "$SCRIPT_NAME" "Javac alternative installed and set." "INFO"
else
    log_message "$SCRIPT_NAME" "update-alternatives command not found. Skipping alternatives configuration." "WARN"
fi

# Source the profile and verify installation
source "${PROFILE_SCRIPT_JDK}" 
if command -v java &> /dev/null; then
    JAVA_VERSION_OUTPUT=$(java -version 2>&1)
    log_message "$SCRIPT_NAME" "Current Java version: ${JAVA_VERSION_OUTPUT}" "INFO"
    
    if [[ "$JAVA_VERSION_OUTPUT" != *"1.8.0_392"* ]]; then
        log_message "$SCRIPT_NAME" "JDK version mismatch after installation. Expected 1.8.0_392." "WARN"
    else
        log_message "$SCRIPT_NAME" "JDK version verification successful." "INFO"
    fi
    
    # Test JavaFX availability
    if "${JAVA_HOME_PATH}/bin/java" -cp "${JAVA_HOME_PATH}/lib/*" -version 2>&1 | grep -q "1.8.0_392"; then
        log_message "$SCRIPT_NAME" "JavaFX-enabled JDK is ready for use." "INFO"
    fi
else
    log_message "$SCRIPT_NAME" "Java command not found after installation and sourcing profile." "ERROR"
    exit 1
fi

log_message "$SCRIPT_NAME" "JDK 8 (Zulu with JavaFX) installation process completed successfully." "INFO"
exit 0