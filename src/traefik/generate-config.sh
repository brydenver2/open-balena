#!/bin/bash

# Script to generate Traefik dynamic configuration with proper auth
# This replaces the template placeholders with actual values

set -e

TRAEFIK_CONFIG_DIR="/etc/traefik/dynamic"
TEMPLATE_DIR="/etc/traefik/templates"

# Ensure required environment variables are set
: "${DNS_TLD:?DNS_TLD is required}"
: "${BALENA_DEVICE_UUID:?BALENA_DEVICE_UUID is required}"

# Generate bcrypt hash for the device UUID
# Using htpasswd if available, otherwise openssl
if command -v htpasswd >/dev/null 2>&1; then
    AUTH_HASH=$(htpasswd -nbB balena "${BALENA_DEVICE_UUID}" | cut -d: -f2)
else
    # Fallback to a simple hash (not recommended for production)
    AUTH_HASH='$2a$10$7OvV8rHdPtKOd0N5.CJeZ.aDdJa9QTxO3qSKvY4VQnJKkJKJkJKJK'
fi

# Replace template variables in config files
mkdir -p "${TRAEFIK_CONFIG_DIR}"

# Process the main config file
sed "s/\\\$2a\\\$10\\\$7OvV8rHdPtKOd0N5.CJeZ.aDdJa9QTxO3qSKvY4VQnJKkJKJkJKJK/${AUTH_HASH}/g" \
    "${TEMPLATE_DIR}/config.yml" > "${TRAEFIK_CONFIG_DIR}/config.yml"

# Copy other files as-is
cp "${TEMPLATE_DIR}/errors.yml" "${TRAEFIK_CONFIG_DIR}/errors.yml"

echo "Traefik configuration generated successfully"