# Additional Environment Variables for Enhanced Services

# These environment variables are automatically generated during setup
# but can be customized if needed

# UI Service Configuration
BANNER_IMAGE=                           # Optional banner image URL for UI
OPENBALENA_API_VERSION=v37.3.4         # API version displayed in UI

# Remote Service Configuration  
REMOTE_SENTRY_DSN=                      # Optional Sentry DSN for error tracking

# Tunnel Configuration
TUNNEL_TOKEN=                           # Cloudflare tunnel token (optional)

# Generated Secrets (automatically created during setup)
COOKIE_SESSION_SECRET=                  # Session cookie encryption key
JSON_WEB_TOKEN_SECRET=                  # JWT signing secret
TOKEN_AUTH_BUILDER_TOKEN=               # Builder service authentication token
REGISTRY2_S3_KEY=                       # S3 access key for registry
REGISTRY2_S3_SECRET=                    # S3 secret key for registry

# Service URLs (automatically configured based on DNS_TLD)
# These are used internally by services for communication
REACT_APP_OPEN_BALENA_UI_URL=https://admin.${DNS_TLD}
REACT_APP_OPEN_BALENA_POSTGREST_URL=https://postgrest.${DNS_TLD}
REACT_APP_OPEN_BALENA_REMOTE_URL=https://remote.${DNS_TLD}
REACT_APP_OPEN_BALENA_API_URL=https://api.${DNS_TLD}

# Database Configuration for PostgREST
PGRST_DB_URI=postgres://docker:docker@db:5432/resin
PGRST_DB_SCHEMA=public
PGRST_DB_ANON_ROLE=docker
PGRST_SERVER_PORT=80

# Service Host Configuration
API_HOST=api.${DNS_TLD}
DELTA_HOST=delta.${DNS_TLD}
BUILDER_HOST=builder.${DNS_TLD}
S3_HOST=s3.${DNS_TLD}

# Storage Configuration
# These are mapped to Docker volumes for persistence
# - builder-storage: Container build artifacts and cache
# - delta-storage: Delta update processing workspace
# - helper-storage: Downloaded files and supervisor releases