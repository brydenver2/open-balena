#!/bin/bash

# Environment Variable Validation Script for open-balena API
# Use this script to validate your API container environment configuration

echo "==> open-balena API Environment Variable Validation"
echo "This script validates that all required environment variables are properly configured."
echo

# Change to the open-balena directory (parent of scripts/)
SCRIPT_DIR="$(dirname "$0")"
if [[ "$SCRIPT_DIR" == *"/scripts" ]]; then
    cd "$(dirname "$SCRIPT_DIR")" || exit 1
else
    cd "$(dirname "$0")" || exit 1
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo "❌ .env file not found!"
    echo "Run './open-balena.sh config' to generate the environment file first."
    exit 1
fi

echo "✅ Found .env file"

# Source environment variables
set -a
source .env
set +a

echo "✅ Loaded environment variables from .env"

# Define required variables based on open-balena-api config.ts
REQUIRED_VARS=(
    "API_HOST"
    "COOKIE_SESSION_SECRET"
    "DELTA_HOST"
    "DEVICE_CONFIG_OPENVPN_CA"
    "VPN_HOST"
    "VPN_PORT"
    "IMAGE_STORAGE_BUCKET"
    "IMAGE_STORAGE_ENDPOINT"
    "JSON_WEB_TOKEN_EXPIRY_MINUTES"
    "JSON_WEB_TOKEN_SECRET"
    "MIXPANEL_TOKEN"
    "REGISTRY2_HOST"
    "TOKEN_AUTH_BUILDER_TOKEN"
    "TOKEN_AUTH_CERT_ISSUER"
    "TOKEN_AUTH_CERT_KEY"
    "TOKEN_AUTH_CERT_KID"
    "TOKEN_AUTH_CERT_PUB"
    "TOKEN_AUTH_JWT_ALGO"
    "VPN_SERVICE_API_KEY"
    "API_VPN_SERVICE_API_KEY"
)

echo
echo "Checking ${#REQUIRED_VARS[@]} required environment variables..."

missing_vars=()
present_vars=()

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    else
        present_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -eq 0 ]]; then
    echo "✅ All ${#REQUIRED_VARS[@]} required variables are present!"
else
    echo "❌ ${#missing_vars[@]} required variables are missing:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo
    echo "Please regenerate your .env file with './open-balena.sh config'"
    exit 1
fi

# Validate docker-compose configuration
echo
echo "Validating docker-compose configuration..."
if docker compose config >/dev/null 2>&1; then
    echo "✅ Docker compose configuration is valid"
else
    echo "❌ Docker compose configuration has errors"
    echo "Run 'docker compose config' to see details"
    exit 1
fi

# Show sample of resolved API environment in docker-compose
echo
echo "Sample of resolved API environment variables:"
docker compose config 2>/dev/null | grep -A 50 "api:" | grep -E "API_HOST|JSON_WEB_TOKEN_SECRET|MIXPANEL_TOKEN|TOKEN_AUTH_CERT_ISSUER|VPN_SERVICE_API_KEY" | head -5 | sed 's/^/  /'

echo
echo "🎉 SUCCESS: API container environment is properly configured!"
echo
echo "Your API container should now have all required environment variables."
echo "You can start open-balena with: ./open-balena.sh up"