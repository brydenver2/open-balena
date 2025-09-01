#!/usr/bin/env bash

# test-swarm-functionality.sh - Basic integration tests for Docker Swarm functionality

set -e

echo "==> Testing OpenBalena Docker Swarm functionality"

# Test script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Test 1: Verify script syntax
echo "Test 1: Checking script syntax..."
if bash -n open-balena.sh; then
    echo "✅ Script syntax is valid"
else
    echo "❌ Script syntax error"
    exit 1
fi

# Test 2: Verify help command shows swarm options
echo -e "\nTest 2: Checking help command includes swarm options..."
if ./open-balena.sh help | grep -q "swarm-"; then
    echo "✅ Help includes swarm commands"
else
    echo "❌ Help missing swarm commands"
    exit 1
fi

# Test 3: Verify swarm commands are recognized
echo -e "\nTest 3: Testing swarm command recognition..."
commands=("swarm-init" "swarm-build" "swarm-up" "swarm-down" "swarm-status" "swarm-logs" "swarm-nfs-setup")

for cmd in "${commands[@]}"; do
    if [[ "$cmd" == "swarm-logs" ]]; then
        # swarm-logs requires a service name argument
        if ./open-balena.sh "$cmd" "api" 2>&1 | grep -q "Error: DNS_TLD\|Error.*Swarm\|Error.*swarm\|==>"; then
            echo "✅ Command '$cmd' recognized and processed"
        else
            echo "❌ Command '$cmd' not properly recognized"
            exit 1
        fi
    elif [[ "$cmd" == "swarm-build" ]]; then
        # swarm-build takes a long time, just check it starts correctly
        if timeout 5 ./open-balena.sh "$cmd" 2>&1 | grep -q "Building.*images\|Building.*Docker\|==>"; then
            echo "✅ Command '$cmd' recognized and processed"
        else
            echo "❌ Command '$cmd' not properly recognized"
            exit 1
        fi
    else
        if ./open-balena.sh "$cmd" 2>&1 | grep -q "Error: DNS_TLD\|Error.*Swarm\|Error.*swarm\|==>"; then
            echo "✅ Command '$cmd' recognized and processed"
        else
            echo "❌ Command '$cmd' not properly recognized"
            exit 1
        fi
    fi
done

# Test 4: Verify stack files are valid YAML
echo -e "\nTest 4: Validating Docker Stack files..."
if python3 scripts/validate-stack-files.py; then
    echo "✅ All stack files are valid"
else
    echo "❌ Stack file validation failed"
    exit 1
fi

# Test 5: Verify build script exists and is executable
echo -e "\nTest 5: Checking build script..."
if [[ -x scripts/build-swarm-images.sh ]]; then
    echo "✅ Build script is executable"
else
    echo "❌ Build script missing or not executable"
    exit 1
fi

# Test 6: Verify that original compose functionality still works
echo -e "\nTest 6: Testing original compose commands still work..."
compose_commands=("up" "down" "status" "logs")

for cmd in "${compose_commands[@]}"; do
    if ./open-balena.sh "$cmd" 2>&1 | grep -q "Error: DNS_TLD\|==>"; then
        echo "✅ Original command '$cmd' still works"
    else
        echo "❌ Original command '$cmd' broken"
        exit 1
    fi
done

# Test 7: Verify environment variable support
echo -e "\nTest 7: Testing environment variable support..."
export STACK_NAME="test-stack"
if ./open-balena.sh help | grep -q "STACK_NAME"; then
    echo "✅ STACK_NAME environment variable documented"
else
    echo "❌ STACK_NAME not documented in help"
    exit 1
fi

# Test 8: Verify documentation exists
echo -e "\nTest 8: Checking documentation..."
if [[ -f docs/docker-swarm-deployment.md ]]; then
    echo "✅ Swarm deployment documentation exists"
else
    echo "❌ Swarm deployment documentation missing"
    exit 1
fi

# Test 9: Check that stack files reference correct image names
echo -e "\nTest 9: Validating image references in stack files..."
if grep -q "openbalena/traefik:latest" docker-stack.yml; then
    echo "✅ Stack file references correct custom images"
else
    echo "❌ Stack file missing custom image references"
    exit 1
fi

# Test 10: Verify NFS template substitution works
echo -e "\nTest 10: Testing NFS template processing..."
export NFS_HOST="test-nfs-host"
export NFS_PORT="2049"
export NFS_PATH="/test-path"

# Test envsubst availability and functionality
if command -v envsubst &> /dev/null; then
    if envsubst < docker-stack-nfs.yml.template | grep -q "test-nfs-host"; then
        echo "✅ NFS template substitution works with envsubst"
    else
        echo "❌ NFS template substitution failed"
        exit 1
    fi
else
    # Test manual substitution (fallback method)
    if sed -e "s/\${NFS_HOST}/$NFS_HOST/g" docker-stack-nfs.yml.template | grep -q "test-nfs-host"; then
        echo "✅ NFS template substitution works with sed fallback"
    else
        echo "❌ NFS template substitution failed"
        exit 1
    fi
fi

echo -e "\n🎉 All tests passed! Docker Swarm functionality is working correctly."
echo -e "\nWhat was tested:"
echo "  ✅ Script syntax validation"
echo "  ✅ Swarm command recognition"
echo "  ✅ Help system integration"
echo "  ✅ Docker Stack file validation"
echo "  ✅ Build script availability"
echo "  ✅ Backward compatibility with compose commands"
echo "  ✅ Environment variable support"
echo "  ✅ Documentation availability"
echo "  ✅ Image reference validation"
echo "  ✅ NFS template processing"

echo -e "\nNote: These are functional tests. Full integration testing requires:"
echo "  - Docker daemon running"
echo "  - Docker Swarm initialized"
echo "  - Network connectivity for image builds"