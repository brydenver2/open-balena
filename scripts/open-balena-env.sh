#!/usr/bin/env bash

echo "=== open-balena Environment Setup ==="

ENV_FILE=".env"
echo "# open-balena environment file" > "$ENV_FILE"

generate_token() {
  # Generates a 64-character hex string
  head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

ask_var() {
  local var="$1"
  local prompt="$2"
  local secret="$3"
  local val
  while true; do
    if [ "$secret" = "1" ]; then
      read -rsp "$prompt: " val; echo
    else
      read -rp "$prompt: " val
    fi
    if [ -z "$val" ]; then
      echo "  Value required!"
    else
      printf -v "$var" '%s' "$val"
      break
    fi
  done
  echo "$var=\"${val//\"/\\\"}\"" >> "$ENV_FILE"
}

# TOKENS_MODE logic
while true; do
  read -rp "Token mode: auto-generate all service tokens or provide your own? [auto/user]: " TOKENS_MODE
  case "$TOKENS_MODE" in
    auto|user) break ;;
    *) echo "Please enter 'auto' or 'user'." ;;
  esac
done
echo "TOKENS_MODE=\"$TOKENS_MODE\"" >> "$ENV_FILE"

# Core variables
ask_var DNS_TLD "Enter your DNS TLD (e.g. mydomain.com)"
ask_var SUPERUSER_EMAIL "Enter superuser email"
ask_var SUPERUSER_PASSWORD "Enter superuser password" 1
ask_var TUNNEL_TOKEN "Enter your cloudflared TUNNEL_TOKEN"

# Device UUID for Traefik configuration
read -rp "Enter BALENA_DEVICE_UUID (or press Enter to generate): " device_uuid
if [[ -z "$device_uuid" ]]; then
  device_uuid=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  echo "Generated BALENA_DEVICE_UUID: $device_uuid"
fi
echo "BALENA_DEVICE_UUID=\"$device_uuid\"" >> "$ENV_FILE"

# External Postgres
read -rp "Use external Postgres DB? [y/N]: " use_pg
if [[ "$use_pg" =~ ^[Yy]$ ]]; then
  EXTERNAL_POSTGRES=true
  echo "EXTERNAL_POSTGRES=true" >> "$ENV_FILE"
  ask_var EXTERNAL_POSTGRES_HOST "External Postgres Host"
  ask_var EXTERNAL_POSTGRES_PORT "External Postgres Port (default 5432)"
  ask_var EXTERNAL_POSTGRES_USER "External Postgres User"
  ask_var EXTERNAL_POSTGRES_PASSWORD "External Postgres Password" 1
  ask_var EXTERNAL_POSTGRES_DATABASE "External Postgres Database"
else
  EXTERNAL_POSTGRES=false
  echo "EXTERNAL_POSTGRES=false" >> "$ENV_FILE"
fi

# External S3/Minio
read -rp "Use external S3/MinIO? [y/N]: " use_s3
if [[ "$use_s3" =~ ^[Yy]$ ]]; then
  EXTERNAL_S3=true
  echo "EXTERNAL_S3=true" >> "$ENV_FILE"
  ask_var EXTERNAL_S3_ENDPOINT "S3 Endpoint"
  ask_var EXTERNAL_S3_ACCESS_KEY "S3 Access Key"
  ask_var EXTERNAL_S3_SECRET_KEY "S3 Secret Key" 1
  ask_var EXTERNAL_S3_REGION "S3 Region (default us-east-1)"
else
  EXTERNAL_S3=false
  echo "EXTERNAL_S3=false" >> "$ENV_FILE"
fi

# ACME/SSL automation
read -rp "Enable automatic SSL (ACME)? [y/N]: " use_acme
if [[ "$use_acme" =~ ^[Yy]$ ]]; then
  ask_var ACME_EMAIL "ACME admin email"
  read -rp "Use Cloudflare for DNS? [y/N, else Gandi]: " use_cf
  if [[ "$use_cf" =~ ^[Yy]$ ]]; then
    ask_var CLOUDFLARE_API_TOKEN "Cloudflare API token" 1
  else
    ask_var GANDI_API_TOKEN "Gandi API token" 1
  fi
fi

# NODE_EXTRA_CA_CERTS for self-signed PKI
read -rp "Using self-signed PKI for your open-balena server? [y/N]: " use_ca
if [[ "$use_ca" =~ ^[Yy]$ ]]; then
  ask_var NODE_EXTRA_CA_CERTS "Path to CA certificate (e.g. /path/to/ca.pem)"
fi

# UI Service Configuration
echo "# UI Service Configuration" >> "$ENV_FILE"
read -rp "Enter banner image URL for UI (default: ./banner_illustration.svg): " banner_image
REACT_APP_BANNER_IMAGE="${banner_image:-./banner_illustration.svg}"
echo "REACT_APP_BANNER_IMAGE=\"$REACT_APP_BANNER_IMAGE\"" >> "$ENV_FILE"

read -rp "Enter OpenBalena API version (default: v37.3.4): " api_version
OPENBALENA_API_VERSION="${api_version:-v37.3.4}"
echo "OPENBALENA_API_VERSION=\"$OPENBALENA_API_VERSION\"" >> "$ENV_FILE"

# PostgREST Service Configuration
if [[ "$EXTERNAL_POSTGRES" = "true" ]]; then
  PGRST_DB_URI="postgres://${EXTERNAL_POSTGRES_USER}:${EXTERNAL_POSTGRES_PASSWORD}@${EXTERNAL_POSTGRES_HOST}:${EXTERNAL_POSTGRES_PORT}/${EXTERNAL_POSTGRES_DATABASE}"
else
  PGRST_DB_URI="postgres://docker:docker@db:5432/resin"
fi
PGRST_DB_SCHEMA="public"
OPENBALENA_DB_ROLE="docker"
{
  echo "# PostgREST Service Configuration"
  echo "PGRST_DB_URI=\"$PGRST_DB_URI\""
  echo "PGRST_DB_SCHEMA=\"$PGRST_DB_SCHEMA\""
  echo "OPENBALENA_DB_ROLE=\"$OPENBALENA_DB_ROLE\""
} >> "$ENV_FILE"

# Builder Service Configuration
echo "# Builder Service Configuration" >> "$ENV_FILE"
read -rp "Enter AMD64 Docker host for builder (format: tcp://host:2375, optional): " docker_host_amd64
DOCKER_HOST_AMD64="${docker_host_amd64:-}"
echo "DOCKER_HOST_AMD64=\"$DOCKER_HOST_AMD64\"" >> "$ENV_FILE"

read -rp "Enter ARM64 Docker host for builder (format: tcp://host:2375, optional): " docker_host_arm64
DOCKER_HOST_ARM64="${docker_host_arm64:-}"
echo "DOCKER_HOST_ARM64=\"$DOCKER_HOST_ARM64\"" >> "$ENV_FILE"

# Helper Service Configuration
echo "# Helper Service Configuration" >> "$ENV_FILE"
read -rp "Enter image storage bucket name (default: resin-production-img-cloudformation): " img_bucket
IMAGE_STORAGE_BUCKET="${img_bucket:-resin-production-img-cloudformation}"
echo "IMAGE_STORAGE_BUCKET=\"$IMAGE_STORAGE_BUCKET\"" >> "$ENV_FILE"

read -rp "Enter image storage prefix (default: images): " img_prefix
IMAGE_STORAGE_PREFIX="${img_prefix:-images}"
echo "IMAGE_STORAGE_PREFIX=\"$IMAGE_STORAGE_PREFIX\"" >> "$ENV_FILE"

# Set IMAGE_STORAGE_ENDPOINT based on external S3 configuration
if [[ "$EXTERNAL_S3" = "true" ]]; then
  IMAGE_STORAGE_ENDPOINT="$EXTERNAL_S3_ENDPOINT"
  IMAGE_STORAGE_ACCESS_KEY="$EXTERNAL_S3_ACCESS_KEY"
  IMAGE_STORAGE_SECRET_KEY="$EXTERNAL_S3_SECRET_KEY"
else
  IMAGE_STORAGE_ENDPOINT="s3.${DNS_TLD}"
  IMAGE_STORAGE_ACCESS_KEY="$REGISTRY2_S3_KEY"
  IMAGE_STORAGE_SECRET_KEY="$REGISTRY2_S3_SECRET"
fi
{
  echo "IMAGE_STORAGE_ENDPOINT=\"$IMAGE_STORAGE_ENDPOINT\""
  echo "IMAGE_STORAGE_ACCESS_KEY=\"$IMAGE_STORAGE_ACCESS_KEY\""
  echo "IMAGE_STORAGE_SECRET_KEY=\"$IMAGE_STORAGE_SECRET_KEY\""
  echo "IMAGE_STORAGE_FORCE_PATH_STYLE=\"true\""
} >> "$ENV_FILE"

# Service URLs (automatically configured based on DNS_TLD)
REACT_APP_OPEN_BALENA_UI_URL="https://admin.${DNS_TLD}"
REACT_APP_OPEN_BALENA_POSTGREST_URL="https://postgrest.${DNS_TLD}"
REACT_APP_OPEN_BALENA_REMOTE_URL="https://remote.${DNS_TLD}"
REACT_APP_OPEN_BALENA_API_URL="https://api.${DNS_TLD}"
{
  echo "# Service URLs (automatically configured based on DNS_TLD)"
  echo "# These are used internally by services for communication"
  echo "REACT_APP_OPEN_BALENA_UI_URL=\"$REACT_APP_OPEN_BALENA_UI_URL\""
  echo "REACT_APP_OPEN_BALENA_POSTGREST_URL=\"$REACT_APP_OPEN_BALENA_POSTGREST_URL\""
  echo "REACT_APP_OPEN_BALENA_REMOTE_URL=\"$REACT_APP_OPEN_BALENA_REMOTE_URL\""
  echo "REACT_APP_OPEN_BALENA_API_URL=\"$REACT_APP_OPEN_BALENA_API_URL\""
} >> "$ENV_FILE"

# Service Host Configuration
API_HOST="api.${DNS_TLD}"
DELTA_HOST="delta.${DNS_TLD}"
BUILDER_HOST="builder.${DNS_TLD}"
REGISTRY_HOST="registry.${DNS_TLD}"
REGISTRY2_HOST="registry.${DNS_TLD}"
{
  echo "# Service Host Configuration"
  echo "# These are used for internal service communication as hostnames"
  echo "API_HOST=\"$API_HOST\""
  echo "DELTA_HOST=\"$DELTA_HOST\""
  echo "BUILDER_HOST=\"$BUILDER_HOST\""
  echo "REGISTRY_HOST=\"$REGISTRY_HOST\""
  echo "REGISTRY2_HOST=\"$REGISTRY2_HOST\""
} >> "$ENV_FILE"

# -- TOKENS SECTION --
TOKEN_VARS=(
  COOKIE_SESSION_SECRET
  JSON_WEB_TOKEN_SECRET
  TOKEN_AUTH_BUILDER_TOKEN
  REGISTRY2_SECRETKEY
  REGISTRY2_S3_KEY
  REGISTRY2_S3_SECRET
  API_SERVICE_API_KEY
  VPN_SERVICE_API_KEY
  VPN_GUEST_API_KEY
  MIXPANEL_TOKEN
  AUTH_RESINOS_REGISTRY_CODE
)
if [[ "$TOKENS_MODE" == "auto" ]]; then
  echo "# Service tokens (auto-generated)" >> "$ENV_FILE"
  for v in "${TOKEN_VARS[@]}"; do
    gensecret=$(generate_token)
    echo "$v=\"$gensecret\"" >> "$ENV_FILE"
    export "$v=$gensecret"
  done
else
  echo "# Service tokens (user-supplied or generated)" >> "$ENV_FILE"
  for v in "${TOKEN_VARS[@]}"; do
    read -rsp "Enter value for $v (leave blank for random): " val; echo
    if [ -z "$val" ]; then
      val=$(generate_token)
      echo "  ($v auto-generated)"
    fi
    echo "$v=\"$val\"" >> "$ENV_FILE"
    export "$v=$val"
  done
fi

# Certificate and Authentication Configuration
echo "# Certificate and Authentication Configuration" >> "$ENV_FILE"
TOKEN_AUTH_CERT_ISSUER="api"
TOKEN_AUTH_CERT_KEY="/certs/private/api.key"
TOKEN_AUTH_CERT_KID="1"
TOKEN_AUTH_CERT_PUB="/certs/public/api.pem"
TOKEN_AUTH_JWT_ALGO="ES256"
DEVICE_CONFIG_OPENVPN_CA="/certs/public/ca.pem"
VPN_HOST="cloudlink.${DNS_TLD}"
VPN_PORT="443"
API_VPN_SERVICE_API_KEY="${API_SERVICE_API_KEY}"
JSON_WEB_TOKEN_EXPIRY_MINUTES="10080"
{
  echo "TOKEN_AUTH_CERT_ISSUER=\"$TOKEN_AUTH_CERT_ISSUER\""
  echo "TOKEN_AUTH_CERT_KEY=\"$TOKEN_AUTH_CERT_KEY\""
  echo "TOKEN_AUTH_CERT_KID=\"$TOKEN_AUTH_CERT_KID\""
  echo "TOKEN_AUTH_CERT_PUB=\"$TOKEN_AUTH_CERT_PUB\""
  echo "TOKEN_AUTH_JWT_ALGO=\"$TOKEN_AUTH_JWT_ALGO\""
  echo "DEVICE_CONFIG_OPENVPN_CA=\"$DEVICE_CONFIG_OPENVPN_CA\""
  echo "VPN_HOST=\"$VPN_HOST\""
  echo "VPN_PORT=\"$VPN_PORT\""
  echo "API_VPN_SERVICE_API_KEY=\"$API_VPN_SERVICE_API_KEY\""
  echo "JSON_WEB_TOKEN_EXPIRY_MINUTES=\"$JSON_WEB_TOKEN_EXPIRY_MINUTES\""
} >> "$ENV_FILE"

# WebResources S3 Configuration
echo "# WebResources S3 Configuration" >> "$ENV_FILE"
if [[ "$EXTERNAL_S3" = "true" ]]; then
  WEBRESOURCES_S3_HOST="$EXTERNAL_S3_ENDPOINT"
  WEBRESOURCES_S3_ACCESS_KEY="$EXTERNAL_S3_ACCESS_KEY"
  WEBRESOURCES_S3_SECRET_KEY="$EXTERNAL_S3_SECRET_KEY"
  WEBRESOURCES_S3_REGION="$EXTERNAL_S3_REGION"
else
  WEBRESOURCES_S3_HOST="s3.${DNS_TLD}"
  WEBRESOURCES_S3_ACCESS_KEY="$REGISTRY2_S3_KEY"
  WEBRESOURCES_S3_SECRET_KEY="$REGISTRY2_S3_SECRET"
  WEBRESOURCES_S3_REGION="us-east-1"
fi
WEBRESOURCES_S3_BUCKET="web-resources"
{
  echo "WEBRESOURCES_S3_HOST=\"$WEBRESOURCES_S3_HOST\""
  echo "WEBRESOURCES_S3_ACCESS_KEY=\"$WEBRESOURCES_S3_ACCESS_KEY\""
  echo "WEBRESOURCES_S3_SECRET_KEY=\"$WEBRESOURCES_S3_SECRET_KEY\""
  echo "WEBRESOURCES_S3_BUCKET=\"$WEBRESOURCES_S3_BUCKET\""
  echo "WEBRESOURCES_S3_REGION=\"$WEBRESOURCES_S3_REGION\""
} >> "$ENV_FILE"

# Export all variables in current shell
export DNS_TLD SUPERUSER_EMAIL SUPERUSER_PASSWORD TUNNEL_TOKEN
export EXTERNAL_POSTGRES EXTERNAL_S3
[ "$EXTERNAL_POSTGRES" = "true" ] && export EXTERNAL_POSTGRES_HOST EXTERNAL_POSTGRES_PORT EXTERNAL_POSTGRES_USER EXTERNAL_POSTGRES_PASSWORD EXTERNAL_POSTGRES_DATABASE
[ "$EXTERNAL_S3" = "true" ] && export EXTERNAL_S3_ENDPOINT EXTERNAL_S3_ACCESS_KEY EXTERNAL_S3_SECRET_KEY EXTERNAL_S3_REGION
[ -n "$ACME_EMAIL" ] && export ACME_EMAIL
[ -n "$CLOUDFLARE_API_TOKEN" ] && export CLOUDFLARE_API_TOKEN
[ -n "$GANDI_API_TOKEN" ] && export GANDI_API_TOKEN
[ -n "$NODE_EXTRA_CA_CERTS" ] && export NODE_EXTRA_CA_CERTS

# Export enhanced service configuration variables
export REACT_APP_BANNER_IMAGE OPENBALENA_API_VERSION
export PGRST_DB_URI PGRST_DB_SCHEMA OPENBALENA_DB_ROLE
export DOCKER_HOST_AMD64 DOCKER_HOST_ARM64
export IMAGE_STORAGE_ENDPOINT IMAGE_STORAGE_BUCKET IMAGE_STORAGE_PREFIX IMAGE_STORAGE_ACCESS_KEY IMAGE_STORAGE_SECRET_KEY IMAGE_STORAGE_FORCE_PATH_STYLE
export REACT_APP_OPEN_BALENA_UI_URL REACT_APP_OPEN_BALENA_POSTGREST_URL REACT_APP_OPEN_BALENA_REMOTE_URL REACT_APP_OPEN_BALENA_API_URL
export API_HOST DELTA_HOST BUILDER_HOST REGISTRY_HOST REGISTRY2_HOST

# Export certificate and authentication variables
export TOKEN_AUTH_CERT_ISSUER TOKEN_AUTH_CERT_KEY TOKEN_AUTH_CERT_KID TOKEN_AUTH_CERT_PUB TOKEN_AUTH_JWT_ALGO
export DEVICE_CONFIG_OPENVPN_CA VPN_HOST VPN_PORT API_VPN_SERVICE_API_KEY JSON_WEB_TOKEN_EXPIRY_MINUTES
export WEBRESOURCES_S3_HOST WEBRESOURCES_S3_ACCESS_KEY WEBRESOURCES_S3_SECRET_KEY WEBRESOURCES_S3_BUCKET WEBRESOURCES_S3_REGION

echo
echo "Environment variables exported to your shell."
echo "All values have been saved to .env in the current directory."
echo "You can now start open-balena with these settings!"

echo
echo "==> To use TOKENS_MODE in docker-compose.yml, conditionally include the token secrets:"
echo "   For example (yaml):"
echo "      environment:"
echo "        COOKIE_SESSION_SECRET: \${TOKENS_MODE:-user} == 'user' ? \${COOKIE_SESSION_SECRET} : ''"
echo "   Or use a shell substitution in your entrypoint if needed."
