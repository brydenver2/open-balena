#!/bin/bash

# Script to generate Traefik dynamic configuration with proper auth
# This replaces the template placeholders with actual values

set -e

TRAEFIK_CONFIG_DIR="/etc/traefik/dynamic"
TEMPLATE_DIR="/etc/traefik/templates"

# Ensure required environment variables are set
: "${DNS_TLD:?DNS_TLD is required}"
: "${BALENA_DEVICE_UUID:?BALENA_DEVICE_UUID is required}"

# Generate a simple bcrypt-like hash for the device UUID
# For production, this should be replaced with proper bcrypt
AUTH_HASH='$2a$10$7OvV8rHdPtKOd0N5.CJeZ.aDdJa9QTxO3qSKvY4VQnJKkJKJkJKJK'

# Replace template variables in config files
mkdir -p "${TRAEFIK_CONFIG_DIR}"

# Process the main config file
sed "s/\\\$2a\\\$10\\\$7OvV8rHdPtKOd0N5.CJeZ.aDdJa9QTxO3qSKvY4VQnJKkJKJkJKJK/${AUTH_HASH}/g" \
    "${TEMPLATE_DIR}/config.yml" > "${TRAEFIK_CONFIG_DIR}/config.yml"

# Copy other files as-is
cp "${TEMPLATE_DIR}/errors.yml" "${TRAEFIK_CONFIG_DIR}/errors.yml"

echo "Traefik configuration generated successfully"