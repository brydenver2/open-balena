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

# Validate required environment variables
check_dns_tld() {
    if [[ -z "${DNS_TLD:-}" ]]; then
        echo "Error: DNS_TLD is not set. Please run 'config' command first or set DNS_TLD environment variable."
        exit 1
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
  logs      Show logs for a service (usage: $0 logs SERVICE_NAME)
  status    Show status of all services
  showenv   Show current .env configuration
  showpass  Show superuser password

Environment Variables:
  DNS_TLD                   - Your domain (required)
  EXTERNAL_POSTGRES         - Use external PostgreSQL (default: false)
  EXTERNAL_S3               - Use external S3 (default: false)
  SUPERUSER_EMAIL           - Admin email (default: admin@\$DNS_TLD)
  VERBOSE                   - Enable verbose output (default: false)

Examples:
  $0 config                 # Generate .env configuration
  $0 up                     # Start all services
  $0 auto-pki               # Start with automatic LetsEncrypt certificates
  $0 custom-pki             # Start with custom certificates
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
    if docker compose ps cert-manager --format json 2>/dev/null | jq -r '.State' | grep -q "running"; then
        echo "==> Checking certificate manager status..."
        if docker compose exec cert-manager ls -la /certs/export/chain.pem 2>/dev/null; then
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
    docker compose exec cert-manager rm -f /certs/export/chain.pem 2>/dev/null || true
    
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
    
    # Start services
    docker compose "${profiles[@]}" up -d --remove-orphans
    
    echo "==> Waiting for API service to become healthy..."
    wait_for_service "api"
    
    echo "==> Services started successfully!"
    show_env
    show_password
}

# Stop services
stop_services() {
    echo "==> Stopping OpenBalena services..."
    docker compose down
    echo "✓ Services stopped."
}

# Restart services
restart_services() {
    echo "==> Restarting OpenBalena services..."
    docker compose restart
    echo "==> Waiting for API service to become healthy..."
    wait_for_service "api"
    echo "✓ Services restarted."
}

# Destroy services and volumes
destroy_services() {
    echo "==> Destroying OpenBalena services and volumes..."
    docker compose down --volumes --remove-orphans
    echo "✓ Services and volumes destroyed."
}

# Wait for service to be healthy
wait_for_service() {
    local service="$1"
    local timeout=300  # 5 minutes timeout
    local elapsed=0
    
    echo -n "Waiting for $service to be healthy"
    while [[ $elapsed -lt $timeout ]]; do
        if [[ "$(docker compose ps "$service" --format json 2>/dev/null | jq -r '.Health' 2>/dev/null)" == "healthy" ]]; then
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
    
    echo -n "Waiting for $service log: $log_pattern"
    while [[ $elapsed -lt $timeout ]]; do
        if docker compose logs "$service" | grep -Eq "$log_pattern"; then
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
        docker compose config --services | sort
        exit 1
    fi
    
    docker compose logs -f "$service"
}

# Show service status
show_status() {
    echo "==> OpenBalena service status:"
    docker compose ps
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
    if docker compose exec -T api cat config/env 2>/dev/null | grep SUPERUSER_PASSWORD; then
        echo
    else
        echo "Could not retrieve superuser password. Make sure API service is running."
    fi
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