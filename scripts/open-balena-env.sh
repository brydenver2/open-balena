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

# Remote Service Configuration
echo "# Remote Service Configuration" >> "$ENV_FILE"
read -rp "Enter Sentry DSN for remote service (optional): " remote_sentry
REMOTE_SENTRY_DSN="${remote_sentry:-}"
echo "REMOTE_SENTRY_DSN=\"$REMOTE_SENTRY_DSN\"" >> "$ENV_FILE"

# PostgREST Service Configuration
if [[ "$EXTERNAL_POSTGRES" = "true" ]]; then
  PGRST_DB_URI="postgres://${EXTERNAL_POSTGRES_USER}:${EXTERNAL_POSTGRES_PASSWORD}@${EXTERNAL_POSTGRES_HOST}:${EXTERNAL_POSTGRES_PORT}/${EXTERNAL_POSTGRES_DATABASE}"
else
  PGRST_DB_URI="postgres://docker:docker@db:5432/resin"
fi
PGRST_DB_SCHEMA="public"
PGRST_DB_ANON_ROLE="docker"
PGRST_SERVER_PORT="80"
{
  echo "# PostgREST Service Configuration"
  echo "PGRST_DB_URI=\"$PGRST_DB_URI\""
  echo "PGRST_DB_SCHEMA=\"$PGRST_DB_SCHEMA\""
  echo "PGRST_DB_ANON_ROLE=\"$PGRST_DB_ANON_ROLE\""
  echo "PGRST_SERVER_PORT=\"$PGRST_SERVER_PORT\""
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
S3_HOST="s3.${DNS_TLD}"
{
  echo "# Service Host Configuration"
  echo "# These are used for internal service communication as hostnames"
  echo "API_HOST=\"$API_HOST\""
  echo "DELTA_HOST=\"$DELTA_HOST\""
  echo "BUILDER_HOST=\"$BUILDER_HOST\""
  echo "S3_HOST=\"$S3_HOST\""
} >> "$ENV_FILE"

# -- TOKENS SECTION --
TOKEN_VARS=(
  COOKIE_SESSION_SECRET
  JSON_WEB_TOKEN_SECRET
  TOKEN_AUTH_BUILDER_TOKEN
  REGISTRY2_SECRETKEY
  REGISTRY2_S3_KEY
  REGISTRY2_S3_SECRET
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
export REACT_APP_BANNER_IMAGE OPENBALENA_API_VERSION REMOTE_SENTRY_DSN
export PGRST_DB_URI PGRST_DB_SCHEMA PGRST_DB_ANON_ROLE PGRST_SERVER_PORT
export REACT_APP_OPEN_BALENA_UI_URL REACT_APP_OPEN_BALENA_POSTGREST_URL REACT_APP_OPEN_BALENA_REMOTE_URL REACT_APP_OPEN_BALENA_API_URL
export API_HOST DELTA_HOST BUILDER_HOST S3_HOST

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
