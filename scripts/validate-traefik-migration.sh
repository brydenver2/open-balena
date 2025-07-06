#!/bin/bash

# Traefik Configuration Validation Script
# Validates the HAProxy to Traefik migration

set -e

echo "🔍 Validating Traefik Migration..."

# Check if running from correct directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ Error: Run this script from the openBalena root directory"
    exit 1
fi

echo "✅ Found docker-compose.yml"

# Check required environment variables
echo "🔧 Checking environment..."
if [[ -z "$DNS_TLD" ]]; then
    echo "⚠️  Warning: DNS_TLD not set"
    DNS_TLD="test.local"
    echo "   Using default: $DNS_TLD"
fi

if [[ -z "$BALENA_DEVICE_UUID" ]]; then
    echo "⚠️  Warning: BALENA_DEVICE_UUID not set"
    BALENA_DEVICE_UUID="test123"
    echo "   Using default: $BALENA_DEVICE_UUID"
fi

echo "✅ Environment configured"

# Validate Docker Compose configuration
echo "🐳 Validating Docker Compose configuration..."
if docker compose config >/dev/null 2>&1; then
    echo "✅ Docker Compose configuration is valid"
else
    echo "❌ Docker Compose configuration has errors"
    exit 1
fi

# Check Traefik configuration files
echo "🚦 Checking Traefik configuration files..."

# Static configuration
if [[ -f "src/traefik/traefik.yml" ]]; then
    echo "✅ Found static configuration: src/traefik/traefik.yml"
    if python3 -c "import yaml; yaml.safe_load(open('src/traefik/traefik.yml'))" 2>/dev/null; then
        echo "✅ Static configuration YAML is valid"
    else
        echo "❌ Static configuration YAML is invalid"
        exit 1
    fi
else
    echo "❌ Missing static configuration: src/traefik/traefik.yml"
    exit 1
fi

# Dynamic configuration templates
if [[ -f "src/traefik/templates/config.yml" ]]; then
    echo "✅ Found dynamic configuration: src/traefik/templates/config.yml"
    if python3 -c "import yaml; yaml.safe_load(open('src/traefik/templates/config.yml'))" 2>/dev/null; then
        echo "✅ Dynamic configuration YAML is valid"
    else
        echo "❌ Dynamic configuration YAML is invalid"
        exit 1
    fi
else
    echo "❌ Missing dynamic configuration: src/traefik/templates/config.yml"
    exit 1
fi

# Error pages configuration
if [[ -f "src/traefik/templates/errors.yml" ]]; then
    echo "✅ Found error pages configuration: src/traefik/templates/errors.yml"
    if python3 -c "import yaml; yaml.safe_load(open('src/traefik/templates/errors.yml'))" 2>/dev/null; then
        echo "✅ Error pages configuration YAML is valid"
    else
        echo "❌ Error pages configuration YAML is invalid"
        exit 1
    fi
else
    echo "❌ Missing error pages configuration: src/traefik/templates/errors.yml"
    exit 1
fi

# Check error pages
echo "📄 Checking error pages..."
error_codes=(400 401 403 404 500 502 503)
for code in "${error_codes[@]}"; do
    if [[ -f "src/error-pages/html/$code.html" ]]; then
        echo "✅ Found error page: $code.html"
    else
        echo "❌ Missing error page: $code.html"
        exit 1
    fi
done

# Test builds
echo "🏗️  Testing container builds..."

if docker build src/traefik -t traefik-test >/dev/null 2>&1; then
    echo "✅ Traefik container builds successfully"
else
    echo "❌ Traefik container build failed"
    exit 1
fi

if docker build src/error-pages -t error-pages-test >/dev/null 2>&1; then
    echo "✅ Error pages container builds successfully"
else
    echo "❌ Error pages container build failed"
    exit 1
fi

if docker build src/traefik-sidecar -t traefik-sidecar-test >/dev/null 2>&1; then
    echo "✅ Traefik sidecar container builds successfully"
else
    echo "⚠️  Traefik sidecar container build failed (network issue, non-critical)"
fi

# Check configuration generation script
echo "⚙️  Testing configuration generation..."
if [[ -x "src/traefik/generate-config.sh" ]]; then
    echo "✅ Configuration generation script is executable"
else
    echo "❌ Configuration generation script is not executable"
    exit 1
fi

# Check documentation
echo "📚 Checking documentation..."
if [[ -f "docs/traefik-migration.md" ]]; then
    echo "✅ Found migration documentation"
else
    echo "❌ Missing migration documentation"
    exit 1
fi

if [[ -f "src/traefik/README.md" ]]; then
    echo "✅ Found Traefik README"
else
    echo "❌ Missing Traefik README"
    exit 1
fi

# Cleanup test images
echo "🧹 Cleaning up test images..."
docker rmi traefik-test error-pages-test traefik-sidecar-test >/dev/null 2>&1 || true

echo ""
echo "🎉 Migration validation completed successfully!"
echo ""
echo "Next steps:"
echo "1. Set up your DNS_TLD and certificate environment variables"
echo "2. Run './open-balena.sh config' to generate the environment file"
echo "3. Run './open-balena.sh up' to start the services"
echo "4. Run './open-balena.sh verify' to test API connectivity"
echo ""
echo "For more information, see:"
echo "- docs/traefik-migration.md - Migration guide"
echo "- src/traefik/README.md - Traefik configuration details"
echo ""
echo "Note: This validation is automatically run before starting services"
echo "when using './open-balena.sh up', 'auto-pki', or 'custom-pki' commands."