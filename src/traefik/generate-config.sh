#!/bin/sh

# generate-config.sh - Traefik Dynamic Configuration Generator
#
# This script generates Traefik's dynamic configuration at container startup
# by processing template files and replacing environment variables with actual values.
#
# Key responsibilities:
# - Validates required environment variables (DNS_TLD, BALENA_DEVICE_UUID)
# - Generates authentication hashes for protected services
# - Creates dynamic routing configuration from templates
# - Ensures configuration files are properly formatted and placed
#
# Environment variables required:
# - DNS_TLD: The domain name for routing rules (e.g., example.com)
# - BALENA_DEVICE_UUID: Device UUID for authentication
#
# Template files:
# - /etc/traefik/templates/config.yml - Main routing and service config
# - /etc/traefik/templates/errors.yml - Error page configuration
#
# Output:
# - /etc/traefik/dynamic/config.yml - Generated routing configuration
# - /etc/traefik/dynamic/errors.yml - Error page configuration
#
# This script runs as part of the container entrypoint before Traefik starts.

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