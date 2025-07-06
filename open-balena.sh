#!/usr/bin/env bash

set -e

# open-balena.sh - OpenBalena orchestration script
# Replaces Makefile functionality with shell script commands

# Source .env file if it exists
if [[ -f .env ]]; then
    set -a
    source .env
    set +a
fi

# Set default values
export BALENARC_NO_ANALYTICS=${BALENARC_NO_ANALYTICS:-1}
export ORG_UNIT=${ORG_UNIT:-openBalena}
export PRODUCTION_MODE=${PRODUCTION_MODE:-true}
export STAGING_PKI=${STAGING_PKI:-/usr/local/share/ca-certificates}
export VERBOSE=${VERBOSE:-false}
export EXTERNAL_POSTGRES=${EXTERNAL_POSTGRES:-false}
export EXTERNAL_POSTGRES_PORT=${EXTERNAL_POSTGRES_PORT:-5432}
export EXTERNAL_S3=${EXTERNAL_S3:-false}
export EXTERNAL_S3_REGION=${EXTERNAL_S3_REGION:-us-east-1}
export USE_NFS=${USE_NFS:-false}
export NFS_HOST=${NFS_HOST:-}
export NFS_PORT=${NFS_PORT:-2049}
export NFS_PATH=${NFS_PATH:-/openbalena}

# Validate required environment variables
check_dns_tld() {
    if [[ -z "${DNS_TLD:-}" ]]; then
        echo "Error: DNS_TLD is not set. Please run 'config' command first or set DNS_TLD environment variable."
        exit 1
    fi
}

# Ensure BALENA_DEVICE_UUID is set
check_balena_device_uuid() {
    if [[ -z "${BALENA_DEVICE_UUID:-}" ]]; then
        echo "Error: BALENA_DEVICE_UUID is not set."
        echo "Please run 'config' command first or set BALENA_DEVICE_UUID environment variable."
        printf "You can generate one with: head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \\n'\n"
        exit 1
    fi
}

# Run Traefik migration validation
run_traefik_validation() {
    echo "==> Running Traefik migration validation..."
    if [[ -f "scripts/validate-traefik-migration.sh" ]]; then
        if ! bash scripts/validate-traefik-migration.sh; then
            echo "❌ Traefik migration validation failed. Please fix the issues above before continuing."
            exit 1
        fi
        echo "✅ Traefik migration validation passed."
    else
        echo "⚠️  Warning: scripts/validate-traefik-migration.sh not found. Skipping validation."
    fi
}

# Show help information
show_help() {
    cat << EOF
OpenBalena orchestration script

Usage: $0 COMMAND [OPTIONS]

Commands:
  help      Show this help message
  lint      Lint shell scripts using shellcheck
  verify    Ping the public API endpoint and verify certificates
  config    Regenerate .env file with current environment/context
  up        Start all services
  down      Stop all services
  restart   Restart all services
  destroy   Stop and remove all containers and volumes
  auto-pki  Start all services with automatic PKI (LetsEncrypt/ACME)
  custom-pki Start all services with custom PKI certificates
  nfs-setup Configure NFS volumes for persistent storage
  logs      Show logs for a service (usage: $0 logs SERVICE_NAME)
  status    Show status of all services
  showenv   Show current .env configuration
  showpass  Show superuser password

Environment Variables:
  DNS_TLD                   - Your domain (required)
  BALENA_DEVICE_UUID        - Device UUID for Traefik configuration (required)
  EXTERNAL_POSTGRES         - Use external PostgreSQL (default: false)
  EXTERNAL_S3               - Use external S3 (default: false)
  SUPERUSER_EMAIL           - Admin email (default: admin@\$DNS_TLD)
  VERBOSE                   - Enable verbose output (default: false)
  USE_NFS                   - Use NFS volumes for persistent storage (default: false)
  NFS_HOST                  - NFS server hostname or IP (required when USE_NFS=true)
  NFS_PORT                  - NFS server port (default: 2049)
  NFS_PATH                  - NFS mount path (default: /openbalena)

Notes:
  - The 'up', 'auto-pki', and 'custom-pki' commands run Traefik migration validation
  - DNS_TLD and BALENA_DEVICE_UUID are required for all start commands
  - Use '$0 config' to generate .env file with required environment variables

Examples:
  $0 config                 # Generate .env configuration
  $0 up                     # Start all services
  $0 auto-pki               # Start with automatic LetsEncrypt certificates
  $0 custom-pki             # Start with custom certificates
  $0 nfs-setup              # Configure NFS volumes
  $0 logs api               # Show API service logs
  $0 verify                 # Check API endpoint and certificates
  $0 down                   # Stop all services

EOF
}

# Lint shell scripts
lint_scripts() {
    echo "==> Linting shell scripts with shellcheck..."
    if ! command -v shellcheck &> /dev/null; then
        echo "Error: shellcheck not found. Please install shellcheck."
        exit 1
    fi
    
    # Find all .sh files recursively and lint them
    local script_files
    script_files=$(find . -type f -name "*.sh" -not -path "./.git/*" | sort)
    
    if [[ -z "$script_files" ]]; then
        echo "No shell scripts found to lint."
        return 0
    fi
    
    echo "Found shell scripts to lint:"
    echo "$script_files"
    echo
    
    local failed=0
    while IFS= read -r script; do
        echo "Checking: $script"
        if ! shellcheck --exclude=SC1091,SC2016 "$script"; then
            failed=1
        fi
    done <<< "$script_files"
    
    if [[ $failed -eq 0 ]]; then
        echo "✓ All shell scripts passed linting."
    else
        echo "✗ Some shell scripts failed linting."
        exit 1
    fi
}

# Verify API endpoint and certificate
verify_api() {
    check_dns_tld
    echo "==> Verifying OpenBalena deployment..."
    
    # Test API endpoint
    echo "Testing API endpoint: https://api.${DNS_TLD}/ping"
    if curl --fail --retry 3 --connect-timeout 10 --max-time 30 "https://api.${DNS_TLD}/ping"; then
        echo
        echo "✓ API endpoint is responding."
    else
        echo
        echo "✗ API endpoint failed to respond."
        exit 1
    fi
    
    # Test certificate validity
    echo "==> Verifying SSL certificate..."
    if curl --fail --silent --head --connect-timeout 10 --max-time 30 "https://api.${DNS_TLD}" > /dev/null; then
        echo "✓ SSL certificate is valid."
    else
        echo "⚠ SSL certificate verification failed - this may be expected with self-signed certificates."
    fi
    
    # Test certificate manager if running
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    if "${compose_cmd[@]}" ps cert-manager --format json 2>/dev/null | jq -r '.State' | grep -q "running"; then
        echo "==> Checking certificate manager status..."
        if "${compose_cmd[@]}" exec cert-manager ls -la /certs/export/chain.pem 2>/dev/null; then
            echo "✓ Certificate manager has generated certificates."
        else
            echo "⚠ Certificate manager is running but no certificates found."
        fi
    fi
    
    echo "==> Verification completed."
}

# Generate configuration using existing script
generate_config() {
    echo "==> Generating .env configuration..."
    if [[ -f "scripts/open-balena-env.sh" ]]; then
        exec bash scripts/open-balena-env.sh
    else
        echo "Error: scripts/open-balena-env.sh not found."
        exit 1
    fi
}

# Start services with auto-PKI/LetsEncrypt
start_auto_pki() {
    echo "==> Starting OpenBalena with auto-PKI (LetsEncrypt/ACME)..."
    
    # Run pre-startup validation
    check_dns_tld
    check_balena_device_uuid
    run_traefik_validation
    
    # Ensure .env exists
    if [[ ! -f .env ]]; then
        echo "Error: .env file not found. Run '$0 config' first."
        exit 1
    fi
    
    # Check for required ACME configuration
    if [[ -z "${ACME_EMAIL:-}" ]]; then
        echo "Error: ACME_EMAIL is required for auto-PKI. Please run '$0 config' and enable ACME."
        exit 1
    fi
    
    # Remove existing certificate to force renewal
    echo "Removing existing certificate to force renewal..."
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    "${compose_cmd[@]}" exec cert-manager rm -f /certs/export/chain.pem 2>/dev/null || true
    
    # Start all services
    start_services
    
    # Wait for cert-manager to generate certificates
    echo "==> Waiting for cert-manager to generate certificates..."
    wait_for_log "cert-manager" "/certs/export/chain.pem Certificate will not expire in [0-9] days"
    wait_for_log "cert-manager" "subject=CN = ${DNS_TLD}"
    wait_for_log "cert-manager" "issuer=C = US, O = Let's Encrypt, CN = .*"
    
    # Wait for Traefik to be healthy
    echo "==> Waiting for Traefik reverse proxy..."
    wait_for_service "traefik"
    
    echo "==> Auto-PKI setup completed successfully!"
    show_env
    show_password
}

# Start services with custom PKI certificates
start_custom_pki() {
    echo "==> Starting OpenBalena with custom PKI certificates..."
    
    # Run pre-startup validation
    check_dns_tld
    check_balena_device_uuid
    run_traefik_validation
    
    # Ensure .env exists
    if [[ ! -f .env ]]; then
        echo "Error: .env file not found. Run '$0 config' first."
        exit 1
    fi
    
    # Check for custom certificate configuration
    if [[ -z "${HAPROXY_CRT:-}" && -z "${TRAEFIK_CRT:-}" ]]; then
        echo "Warning: No custom certificate path specified."
        echo "Set HAPROXY_CRT or TRAEFIK_CRT environment variable to use custom certificates."
        echo "Proceeding with standard startup..."
    fi
    
    # Start services normally - custom certificates should be mounted via volumes
    start_services
    
    echo "==> Custom PKI setup completed!"
    show_env
    show_password
}

# Start services with docker compose
start_services() {
    echo "==> Starting OpenBalena services..."
    
    # Run pre-startup validation
    check_dns_tld
    check_balena_device_uuid
    run_traefik_validation
    
    # Ensure .env exists
    if [[ ! -f .env ]]; then
        echo "Error: .env file not found. Run '$0 config' first."
        exit 1
    fi
    
    # Determine which profiles to use based on external services
    local profiles=()
    
    if [[ "${EXTERNAL_POSTGRES:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-postgres")
        echo "Using internal PostgreSQL service"
    else
        echo "Using external PostgreSQL service"
    fi
    
    if [[ "${EXTERNAL_S3:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-s3")
        echo "Using internal S3 service"
    else
        echo "Using external S3 service"
    fi
    
    # Add builder architecture profile
    if [[ "${BUILDER_ARCH:-}" = "amd64" ]]; then
        profiles+=("--profile" "builder-amd64")
        echo "Using AMD64 builder service"
    elif [[ "${BUILDER_ARCH:-}" = "arm64" ]]; then
        profiles+=("--profile" "builder-arm64")
        echo "Using ARM64 builder service"
    else
        echo "Warning: BUILDER_ARCH not set or invalid. No builder service will be started."
        echo "Set BUILDER_ARCH to 'amd64' or 'arm64' to enable builder functionality."
    fi
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
        echo "Using NFS volumes on ${NFS_HOST}:${NFS_PATH}"
    else
        echo "Using local Docker volumes"
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    # Start services
    "${compose_cmd[@]}" "${profiles[@]}" up -d --remove-orphans
    
    echo "==> Waiting for API service to become healthy..."
    wait_for_service "api"
    
    echo "==> Services started successfully!"
    show_env
    show_password
}

# Stop services
stop_services() {
    echo "==> Stopping OpenBalena services..."
    
    # Determine which profiles to use based on external services
    local profiles=()
    
    if [[ "${EXTERNAL_POSTGRES:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-postgres")
    fi
    
    if [[ "${EXTERNAL_S3:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-s3")
    fi
    
    # Add builder architecture profile
    if [[ "${BUILDER_ARCH:-}" = "amd64" ]]; then
        profiles+=("--profile" "builder-amd64")
    elif [[ "${BUILDER_ARCH:-}" = "arm64" ]]; then
        profiles+=("--profile" "builder-arm64")
    fi
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    "${compose_cmd[@]}" "${profiles[@]}" down
    echo "✓ Services stopped."
}

# Restart services
restart_services() {
    echo "==> Restarting OpenBalena services..."
    
    # Determine which profiles to use based on external services
    local profiles=()
    
    if [[ "${EXTERNAL_POSTGRES:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-postgres")
    fi
    
    if [[ "${EXTERNAL_S3:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-s3")
    fi
    
    # Add builder architecture profile
    if [[ "${BUILDER_ARCH:-}" = "amd64" ]]; then
        profiles+=("--profile" "builder-amd64")
    elif [[ "${BUILDER_ARCH:-}" = "arm64" ]]; then
        profiles+=("--profile" "builder-arm64")
    fi
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    "${compose_cmd[@]}" "${profiles[@]}" restart
    echo "==> Waiting for API service to become healthy..."
    wait_for_service "api"
    echo "✓ Services restarted."
}

# Destroy services and volumes
destroy_services() {
    echo "==> Destroying OpenBalena services and volumes..."
    
    # Determine which profiles to use based on external services
    local profiles=()
    
    if [[ "${EXTERNAL_POSTGRES:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-postgres")
    fi
    
    if [[ "${EXTERNAL_S3:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-s3")
    fi
    
    # Add builder architecture profile
    if [[ "${BUILDER_ARCH:-}" = "amd64" ]]; then
        profiles+=("--profile" "builder-amd64")
    elif [[ "${BUILDER_ARCH:-}" = "arm64" ]]; then
        profiles+=("--profile" "builder-arm64")
    fi
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    "${compose_cmd[@]}" "${profiles[@]}" down --volumes --remove-orphans
    echo "✓ Services and volumes destroyed."
}

# Wait for service to be healthy
wait_for_service() {
    local service="$1"
    local timeout=300  # 5 minutes timeout
    local elapsed=0
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    echo -n "Waiting for $service to be healthy"
    while [[ $elapsed -lt $timeout ]]; do
        if [[ $("${compose_cmd[@]}" ps "$service" --format json 2>/dev/null | jq -r '.Health' 2>/dev/null) == "healthy" ]]; then
            echo
            echo "✓ $service is healthy"
            return 0
        fi
        echo -n "."
        sleep 3
        elapsed=$((elapsed + 3))
    done
    
    echo
    echo "✗ Timeout waiting for $service to become healthy"
    return 1
}

# Wait for specific log message from a service
wait_for_log() {
    local service="$1"
    local log_pattern="$2"
    local timeout=300  # 5 minutes timeout
    local elapsed=0
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    echo -n "Waiting for $service log: $log_pattern"
    while [[ $elapsed -lt $timeout ]]; do
        if "${compose_cmd[@]}" logs "$service" | grep -Eq "$log_pattern"; then
            echo
            echo "✓ Found expected log message in $service"
            return 0
        fi
        echo -n "."
        sleep 3
        elapsed=$((elapsed + 3))
    done
    
    echo
    echo "✗ Timeout waiting for log message in $service"
    return 1
}

# Show logs for a service
show_logs() {
    local service="$1"
    if [[ -z "$service" ]]; then
        echo "Usage: $0 logs SERVICE_NAME"
        echo "Available services:"
        
        # Determine which profiles to use based on external services
        local profiles=()
        
        if [[ "${EXTERNAL_POSTGRES:-false}" != "true" ]]; then
            profiles+=("--profile" "internal-postgres")
        fi
        
        if [[ "${EXTERNAL_S3:-false}" != "true" ]]; then
            profiles+=("--profile" "internal-s3")
        fi
        
        # Add builder architecture profile
        if [[ "${BUILDER_ARCH:-}" = "amd64" ]]; then
            profiles+=("--profile" "builder-amd64")
        elif [[ "${BUILDER_ARCH:-}" = "arm64" ]]; then
            profiles+=("--profile" "builder-arm64")
        fi
        
        # Check if NFS volumes should be used
        local compose_files=("docker-compose.yml")
        if use_nfs_volumes; then
            compose_files+=("docker-compose.nfs.yml")
        fi
        
        # Build docker compose command with all files
        local compose_cmd=("docker" "compose")
        for file in "${compose_files[@]}"; do
            compose_cmd+=("-f" "$file")
        done
        
        "${compose_cmd[@]}" "${profiles[@]}" config --services | sort
        exit 1
    fi
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    "${compose_cmd[@]}" logs -f "$service"
}

# Show service status
show_status() {
    echo "==> OpenBalena service status:"
    
    # Determine which profiles to use based on external services
    local profiles=()
    
    if [[ "${EXTERNAL_POSTGRES:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-postgres")
    fi
    
    if [[ "${EXTERNAL_S3:-false}" != "true" ]]; then
        profiles+=("--profile" "internal-s3")
    fi
    
    # Add builder architecture profile
    if [[ "${BUILDER_ARCH:-}" = "amd64" ]]; then
        profiles+=("--profile" "builder-amd64")
        echo "Using AMD64 builder"
    elif [[ "${BUILDER_ARCH:-}" = "arm64" ]]; then
        profiles+=("--profile" "builder-arm64")
        echo "Using ARM64 builder"
    else
        echo "No builder architecture configured"
    fi
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
        echo "Using NFS volumes on ${NFS_HOST}:${NFS_PATH}"
    else
        echo "Using local Docker volumes"
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    "${compose_cmd[@]}" "${profiles[@]}" ps
}

# Show environment configuration
show_env() {
    if [[ -f .env ]]; then
        echo "==> Current .env configuration:"
        cat .env
        echo
    else
        echo "No .env file found. Run '$0 config' to generate one."
    fi
}

# Show superuser password
show_password() {
    echo "==> Superuser password:"
    
    # Check if NFS volumes should be used
    local compose_files=("docker-compose.yml")
    if use_nfs_volumes; then
        compose_files+=("docker-compose.nfs.yml")
    fi
    
    # Build docker compose command with all files
    local compose_cmd=("docker" "compose")
    for file in "${compose_files[@]}"; do
        compose_cmd+=("-f" "$file")
    done
    
    if "${compose_cmd[@]}" exec -T api cat config/env 2>/dev/null | grep SUPERUSER_PASSWORD; then
        echo
    else
        echo "Could not retrieve superuser password. Make sure API service is running."
    fi
}

# Setup NFS volumes
setup_nfs() {
    echo "==> Setting up NFS volumes..."
    
    # Prompt for NFS configuration if not already set
    if [[ -z "${NFS_HOST:-}" ]]; then
        echo "NFS configuration required."
        echo
        echo "Enter NFS server hostname or IP: "
        read -r NFS_HOST
        if [[ -z "$NFS_HOST" ]]; then
            echo "Error: NFS host is required."
            exit 1
        fi
        export NFS_HOST
    fi
    
    if [[ -z "${NFS_PORT:-}" ]]; then
        echo "Enter NFS server port (default: 2049): "
        read -r user_port
        if [[ -n "$user_port" ]]; then
            export NFS_PORT="$user_port"
        else
            export NFS_PORT="2049"
        fi
    fi
    
    if [[ -z "${NFS_PATH:-}" ]]; then
        echo "Enter NFS mount path (default: /openbalena): "
        read -r user_path
        if [[ -n "$user_path" ]]; then
            export NFS_PATH="$user_path"
        else
            export NFS_PATH="/openbalena"
        fi
    fi
    
    echo "==> NFS Configuration:"
    echo "NFS_HOST: $NFS_HOST"
    echo "NFS_PORT: $NFS_PORT"
    echo "NFS_PATH: $NFS_PATH"
    echo
    
    # Test NFS connectivity (optional - skip for now to avoid hanging)
    echo "==> Skipping NFS connectivity test (can cause timeout in some environments)"
    echo "⚠ Please ensure your NFS server is configured and accessible manually."
    
    # Generate NFS-enabled docker-compose override
    echo "==> Generating NFS volume configuration..."
    cat > docker-compose.nfs.yml << EOF
# NFS Volume Configuration
# This file is auto-generated by open-balena.sh nfs-setup command

volumes:
  cert-manager-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/cert-manager-data"
  
  certs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/certs-data"
  
  db-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/db-data"
  
  pki-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/pki-data"
  
  redis-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/redis-data"
  
  resin-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/resin-data"
  
  s3-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/s3-data"
  
  builder-storage:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/builder-storage"
  
  delta-storage:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/delta-storage"
  
  helper-storage:
    driver: local
    driver_opts:
      type: nfs
      o: addr=${NFS_HOST},rw,nfsvers=4,port=${NFS_PORT}
      device: ":${NFS_PATH}/helper-storage"
EOF
    
    echo "✓ NFS volume configuration written to docker-compose.nfs.yml"
    
    # Update .env file with NFS settings
    if [[ -f .env ]]; then
        # Remove existing NFS settings
        sed -i '/^USE_NFS=/d' .env
        sed -i '/^NFS_HOST=/d' .env
        sed -i '/^NFS_PORT=/d' .env
        sed -i '/^NFS_PATH=/d' .env
        
        # Add new NFS settings
        {
            echo ""
            echo "USE_NFS=true"
            echo "NFS_HOST=$NFS_HOST"
            echo "NFS_PORT=$NFS_PORT"
            echo "NFS_PATH=$NFS_PATH"
        } >> .env
        
        echo "✓ .env file updated with NFS configuration"
    else
        echo "Warning: .env file not found. NFS settings not saved."
        echo "Run '$0 config' to generate .env file first."
    fi
    
    echo
    echo "==> NFS setup completed!"
    echo "Your volumes will now be stored on NFS server $NFS_HOST:$NFS_PATH"
    echo "Use '$0 up' to start services with NFS volumes"
    echo
}

# Check if NFS is configured and should be used
use_nfs_volumes() {
    [[ "${USE_NFS:-false}" == "true" ]] && [[ -n "${NFS_HOST:-}" ]] && [[ -f "docker-compose.nfs.yml" ]]
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        help|-h|--help)
            show_help
            ;;
        lint)
            lint_scripts
            ;;
        verify)
            verify_api
            ;;
        config)
            generate_config
            ;;
        up)
            start_services
            ;;
        auto-pki)
            start_auto_pki
            ;;
        custom-pki)
            start_custom_pki
            ;;
        nfs-setup)
            setup_nfs
            ;;
        down)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        destroy)
            destroy_services
            ;;
        logs)
            show_logs "$@"
            ;;
        status)
            show_status
            ;;
        showenv)
            show_env
            ;;
        showpass)
            show_password
            ;;
        *)
            echo "Error: Unknown command '$command'"
            echo "Run '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"