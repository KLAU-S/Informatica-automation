#!/bin/bash

# 05_configure_sqldeveloper.sh
# Configures SQL Developer with database connections

source "$(dirname "$0")/00_config.sh"
SCRIPT_NAME="05_configure_sqldev"
log_message "$SCRIPT_NAME" "Starting SQL Developer configuration process." "INFO"

# Function to create SQL Developer connections XML
create_connections_xml() {
    local connections_file="$1"
    local connections_dir=$(dirname "$connections_file")
    
    log_message "$SCRIPT_NAME" "Creating SQL Developer connections directory: $connections_dir" "INFO"
    mkdir -p "$connections_dir"
    
    cat > "$connections_file" << 'EOF'
<?xml version = '1.0' encoding = 'UTF-8'?>
<References xmlns="http://xmlns.oracle.com/jdeveloper/1013/ide">
   <Reference className="oracle.jdeveloper.db.adapter.DatabaseProvider" xmlns="">
      <Factory className="oracle.jdeveloper.db.adapter.DatabaseProviderFactory1"/>
      <RefAddresses>
         <StringRefAddr addrType="user">
            <Contents>system</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="subtype">
            <Contents>oraJDBC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="customUrl">
            <Contents>jdbc:oracle:thin:@localhost:1521:XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="SavePassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="password">
            <Contents>oracle</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="driver">
            <Contents>oracle.jdbc.OracleDriver</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="DeployPassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="hostname">
            <Contents>localhost</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="port">
            <Contents>1521</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="sid">
            <Contents>XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionName">
            <Contents>SystemDB</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnName">
            <Contents>SystemDB</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="NoPasswordConnection">
            <Contents>FALSE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionType">
            <Contents>BASIC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="RaptorConnectionType">
            <Contents>Oracle</Contents>
         </StringRefAddr>
      </RefAddresses>
   </Reference>
   <Reference className="oracle.jdeveloper.db.adapter.DatabaseProvider" xmlns="">
      <Factory className="oracle.jdeveloper.db.adapter.DatabaseProviderFactory1"/>
      <RefAddresses>
         <StringRefAddr addrType="user">
            <Contents>INFA_DOM</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="subtype">
            <Contents>oraJDBC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="customUrl">
            <Contents>jdbc:oracle:thin:@localhost:1521:XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="SavePassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="password">
            <Contents>INFA_DOM</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="driver">
            <Contents>oracle.jdbc.OracleDriver</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="DeployPassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="hostname">
            <Contents>localhost</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="port">
            <Contents>1521</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="sid">
            <Contents>XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionName">
            <Contents>INFA_DOM</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnName">
            <Contents>INFA_DOM</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="NoPasswordConnection">
            <Contents>FALSE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionType">
            <Contents>BASIC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="RaptorConnectionType">
            <Contents>Oracle</Contents>
         </StringRefAddr>
      </RefAddresses>
   </Reference>
   <Reference className="oracle.jdeveloper.db.adapter.DatabaseProvider" xmlns="">
      <Factory className="oracle.jdeveloper.db.adapter.DatabaseProviderFactory1"/>
      <RefAddresses>
         <StringRefAddr addrType="user">
            <Contents>INFA_REP</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="subtype">
            <Contents>oraJDBC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="customUrl">
            <Contents>jdbc:oracle:thin:@localhost:1521:XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="SavePassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="password">
            <Contents>INFA_REP</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="driver">
            <Contents>oracle.jdbc.OracleDriver</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="DeployPassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="hostname">
            <Contents>localhost</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="port">
            <Contents>1521</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="sid">
            <Contents>XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionName">
            <Contents>INFA_REP</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnName">
            <Contents>INFA_REP</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="NoPasswordConnection">
            <Contents>FALSE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionType">
            <Contents>BASIC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="RaptorConnectionType">
            <Contents>Oracle</Contents>
         </StringRefAddr>
      </RefAddresses>
   </Reference>
   <Reference className="oracle.jdeveloper.db.adapter.DatabaseProvider" xmlns="">
      <Factory className="oracle.jdeveloper.db.adapter.DatabaseProviderFactory1"/>
      <RefAddresses>
         <StringRefAddr addrType="user">
            <Contents>HR</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="subtype">
            <Contents>oraJDBC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="customUrl">
            <Contents>jdbc:oracle:thin:@localhost:1521:XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="SavePassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="password">
            <Contents>HR</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="driver">
            <Contents>oracle.jdbc.OracleDriver</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="DeployPassword">
            <Contents>true</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="hostname">
            <Contents>localhost</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="port">
            <Contents>1521</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="sid">
            <Contents>XE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionName">
            <Contents>HR</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnName">
            <Contents>HR</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="NoPasswordConnection">
            <Contents>FALSE</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="ConnectionType">
            <Contents>BASIC</Contents>
         </StringRefAddr>
         <StringRefAddr addrType="RaptorConnectionType">
            <Contents>Oracle</Contents>
         </StringRefAddr>
      </RefAddresses>
   </Reference>
</References>
EOF

    log_message "$SCRIPT_NAME" "Created SQL Developer connections file: $connections_file" "INFO"
}

# Function to create SQL Developer launcher script
create_sqldeveloper_launcher() {
    local launcher_script="/usr/local/bin/sqldeveloper"
    
    cat > "$launcher_script" << EOF
#!/bin/bash
# SQL Developer Launcher with proper Java configuration

export JAVA_HOME=${JAVA_HOME_PATH}
export PATH=\$JAVA_HOME/bin:\$PATH

# Set SQL Developer home
SQLDEV_HOME=${SQLDEV_INSTALL_PATH}

# Launch SQL Developer
cd "\$SQLDEV_HOME"
exec "\$SQLDEV_HOME/sqldeveloper.sh" "\$@"
EOF

    sudo chmod +x "$launcher_script"
    log_message "$SCRIPT_NAME" "Created SQL Developer launcher: $launcher_script" "INFO"
}

# Function to test database connections
test_database_connections() {
    log_message "$SCRIPT_NAME" "Testing database connections..." "INFO"
    
    # Check if Oracle container is running
    if ! docker ps | grep -q oracle-xe; then
        log_message "$SCRIPT_NAME" "Oracle container is not running. Cannot test connections." "WARN"
        return 1
    fi
    
    # Test connections using sqlplus in the container
    local users=("system/oracle" "INFA_DOM/INFA_DOM" "INFA_REP/INFA_REP" "HR/HR")
    
    for user in "${users[@]}"; do
        if docker exec oracle-xe sqlplus -L "${user}@//localhost:1521/XE" <<< "SELECT USER FROM dual;" &>/dev/null; then
            log_message "$SCRIPT_NAME" "✓ Database connection test successful for: ${user%%/*}" "INFO"
        else
            log_message "$SCRIPT_NAME" "✗ Database connection test failed for: ${user%%/*}" "WARN"
        fi
    done
}

# Main configuration process
log_message "$SCRIPT_NAME" "Checking if SQL Developer is installed..." "INFO"

# Accept multiple install layouts (wrapper or .sh)
SQLDEV_LAUNCHER=""
if [ -x "${SQLDEV_INSTALL_PATH}/sqldeveloper.sh" ]; then
    SQLDEV_LAUNCHER="${SQLDEV_INSTALL_PATH}/sqldeveloper.sh"
elif command -v sqldeveloper >/dev/null 2>&1; then
    SQLDEV_LAUNCHER="$(command -v sqldeveloper)"
else
    # Try common locations
    for cand in \
        /usr/local/bin/sqldeveloper \
        /usr/bin/sqldeveloper \
        /opt/sqldeveloper/sqldeveloper.sh; do
        if [ -x "$cand" ]; then
            SQLDEV_LAUNCHER="$cand"
            break
        fi
    done
fi

if [ -z "$SQLDEV_LAUNCHER" ]; then
    log_message "$SCRIPT_NAME" "SQL Developer launcher not found. Please install it first (Step 04)." "ERROR"
    exit 1
fi
log_message "$SCRIPT_NAME" "SQL Developer launcher detected at: $SQLDEV_LAUNCHER" "INFO"

# Create SQL Developer configuration directory structure
log_message "$SCRIPT_NAME" "Setting up SQL Developer configuration..." "INFO"

# Find the actual SQL Developer version directory
SQLDEV_VERSION_DIR=$(find "${SQLDEV_CONFIG_DIR}" -maxdepth 1 -name "system*" -type d 2>/dev/null | head -n 1)

if [ -z "$SQLDEV_VERSION_DIR" ]; then
    # Create a default version directory structure
    SQLDEV_VERSION_DIR="${SQLDEV_CONFIG_DIR}/system21.4.3.063.0100"
    mkdir -p "$SQLDEV_VERSION_DIR"
    log_message "$SCRIPT_NAME" "Created SQL Developer version directory: $SQLDEV_VERSION_DIR" "INFO"
fi

# Create connections subdirectory
CONNECTIONS_DIR="${SQLDEV_VERSION_DIR}/o.jdeveloper.db.connection.12.2.1.4.42.170908.1359"
CONNECTIONS_FILE="${CONNECTIONS_DIR}/connections.xml"

# Create the connections configuration
create_connections_xml "$CONNECTIONS_FILE"

# Create launcher script
# Create launcher script only if no system wrapper exists
if ! command -v sqldeveloper >/dev/null 2>&1; then
    create_sqldeveloper_launcher
fi

# Test database connections
test_database_connections

# Create a desktop entry for SQL Developer (if running in GUI environment)
if [ -n "${DISPLAY:-}" ] && command -v xdg-desktop-menu &> /dev/null; then
    DESKTOP_FILE="/tmp/sqldeveloper.desktop"
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Oracle SQL Developer
Comment=Oracle SQL Developer
Exec=/usr/local/bin/sqldeveloper
Icon=${SQLDEV_INSTALL_PATH}/icon.png
Type=Application
Categories=Development;Database;
EOF
    
    if xdg-desktop-menu install "$DESKTOP_FILE" 2>/dev/null; then
        log_message "$SCRIPT_NAME" "Created desktop entry for SQL Developer" "INFO"
    fi
    rm -f "$DESKTOP_FILE"
fi

# Provide usage instructions
log_message "$SCRIPT_NAME" "SQL Developer configuration completed!" "INFO"
log_message "$SCRIPT_NAME" "You can now launch SQL Developer using:" "INFO"
log_message "$SCRIPT_NAME" "  - Command line: /usr/local/bin/sqldeveloper" "INFO"
log_message "$SCRIPT_NAME" "  - Direct path: $SQLDEV_LAUNCHER" "INFO"
log_message "$SCRIPT_NAME" "" "INFO"
log_message "$SCRIPT_NAME" "Pre-configured database connections:" "INFO"
log_message "$SCRIPT_NAME" "  - SystemDB (system/oracle)" "INFO"
log_message "$SCRIPT_NAME" "  - INFA_DOM (INFA_DOM/INFA_DOM)" "INFO"
log_message "$SCRIPT_NAME" "  - INFA_REP (INFA_REP/INFA_REP)" "INFO"
log_message "$SCRIPT_NAME" "  - HR (HR/HR)" "INFO"

exit 0