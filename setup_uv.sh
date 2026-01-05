#!/bin/bash

# Script to setup Python virtual environment with uv and custom SSL certificates
# This script creates/syncs uv environment, installs certifi, appends custom certs, and sets environment variables

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="${SCRIPT_DIR}/backend"
CERTS_DIR="/Users/ran1sgp/WorkSpace/BoschCACerts"

echo -e "${GREEN}==> Checking uv installation...${NC}"
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed"
    echo "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "Then add to PATH: source $HOME/.local/bin/env"
    exit 1
fi

echo -e "${GREEN}==> Navigating to project directory...${NC}"
cd "${PROJECT_DIR}"

echo -e "${GREEN}==> Initializing/syncing uv project...${NC}"
# Initialize project if pyproject.toml doesn't exist
if [ ! -f "pyproject.toml" ]; then
    echo "Creating new pyproject.toml..."
    uv init --no-readme --no-workspace
fi

# Create .venv if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Set environment variable to disable SSL verification for uv temporarily
echo -e "${GREEN}==> Installing certifi package (bypassing SSL verification)...${NC}"
UV_NO_VERIFY_SSL=1 uv pip install certifi

echo -e "${GREEN}==> Finding certifi cacert.pem location...${NC}"
# Use the virtual environment's Python directly instead of uv run
CACERT_PATH=$(.venv/bin/python -c "import certifi; print(certifi.where())")
echo "Certifi location: ${CACERT_PATH}"

echo -e "${GREEN}==> Appending custom certificates to cacert.pem...${NC}"
# Append RB IssuingCA certificate
if [ -f "${CERTS_DIR}/RB_IssuingCA_RSA_G21-pem.cer" ]; then
    cat "${CERTS_DIR}/RB_IssuingCA_RSA_G21-pem.cer" >> "${CACERT_PATH}"
    echo "✓ Appended RB_IssuingCA_RSA_G21-pem.cer"
else
    echo -e "${YELLOW}Warning: RB_IssuingCA_RSA_G21-pem.cer not found${NC}"
fi

# Append RB RootCA certificate
if [ -f "${CERTS_DIR}/RB_RootCA_RSA_G01-pem.cer" ]; then
    cat "${CERTS_DIR}/RB_RootCA_RSA_G01-pem.cer" >> "${CACERT_PATH}"
    echo "✓ Appended RB_RootCA_RSA_G01-pem.cer"
else
    echo -e "${YELLOW}Warning: RB_RootCA_RSA_G01-pem.cer not found${NC}"
fi

echo -e "${GREEN}==> Setting SSL environment variables...${NC}"
export SSL_CERT_FILE="${CACERT_PATH}"
export REQUESTS_CA_BUNDLE="${CACERT_PATH}"
export NODE_EXTRA_CA_CERTS="${CACERT_PATH}"
echo "✓ SSL_CERT_FILE=${SSL_CERT_FILE}"
echo "✓ REQUESTS_CA_BUNDLE=${REQUESTS_CA_BUNDLE}"
echo "✓ NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS}"

echo -e "${GREEN}==> Now installing project dependencies with fixed certificates...${NC}"
# Install dependencies (now with proper certificates)
if [ -f "requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    SSL_CERT_FILE="${CACERT_PATH}" REQUESTS_CA_BUNDLE="${CACERT_PATH}" uv pip install -r requirements.txt
else
    echo "Syncing from pyproject.toml..."
    SSL_CERT_FILE="${CACERT_PATH}" REQUESTS_CA_BUNDLE="${CACERT_PATH}" uv sync
fi

echo -e "${GREEN}==> Setup complete!${NC}"
echo ""
echo "To run commands in the uv environment:"
echo -e "${YELLOW}uv run python your_script.py${NC}"
echo -e "${YELLOW}uv run uvicorn main:app${NC}"
echo ""
echo "Or activate the virtual environment:"
echo -e "${YELLOW}source ${PROJECT_DIR}/.venv/bin/activate${NC}"
echo ""
echo "To add the SSL exports to your shell profile (~/.zshrc):"
echo "export SSL_CERT_FILE=${CACERT_PATH}"
echo "export REQUESTS_CA_BUNDLE=${CACERT_PATH}"
echo "export NODE_EXTRA_CA_CERTS=${CACERT_PATH}"
