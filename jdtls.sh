#!/bin/bash
# Script to run the built JDT Language Server
# Usage: ./jdtls.sh [data_directory]

# Get the script directory and find the repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository"

# Check if repository exists
if [ ! -d "${REPO_DIR}" ]; then
    echo "Error: Repository not found at ${REPO_DIR}"
    echo "Please build the project first with: mvn clean install"
    exit 1
fi

# Find the equinox launcher jar
LAUNCHER_JAR=$(find "${REPO_DIR}/plugins" -name "org.eclipse.equinox.launcher_*.jar" | head -1)

if [ -z "${LAUNCHER_JAR}" ]; then
    echo "Error: Equinox launcher jar not found in ${REPO_DIR}/plugins"
    exit 1
fi

# Detect OS and set configuration directory
OS=$(uname -s)
case "${OS}" in
    Linux*)
        CONFIG_DIR="${REPO_DIR}/config_linux"
        ;;
    Darwin*)
        CONFIG_DIR="${REPO_DIR}/config_mac"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        CONFIG_DIR="${REPO_DIR}/config_win"
        ;;
    *)
        echo "Warning: Unknown OS ${OS}, using config_linux"
        CONFIG_DIR="${REPO_DIR}/config_linux"
        ;;
esac

# Set data directory (default to /tmp/jdtls-data if not provided)
DATA_DIR="${1:-/tmp/jdtls-data}"

# Change to repository directory so relative paths work
cd "${REPO_DIR}"

# Run the language server
java \
	-Declipse.application=org.eclipse.jdt.ls.core.id1 \
	-Dosgi.bundles.defaultStartLevel=4 \
	-Declipse.product=org.eclipse.jdt.ls.core.product \
	-Dlog.level=ALL \
	-Xmx1G \
	--add-modules=ALL-SYSTEM \
	--add-opens java.base/java.util=ALL-UNNAMED \
	--add-opens java.base/java.lang=ALL-UNNAMED \
	-jar "${LAUNCHER_JAR}" \
	-configuration "${CONFIG_DIR}" \
	-data "${DATA_DIR}"
