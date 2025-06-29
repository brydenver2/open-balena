#!/bin/sh

# Entrypoint script for Cloudflared tunnel
# Validates that TUNNEL_TOKEN is provided and starts the tunnel

echo "🔍 Cloudflared tunnel starting..."

# Check if TUNNEL_TOKEN is set
if [ -z "${TUNNEL_TOKEN}" ]; then
    echo "❌ ERROR: TUNNEL_TOKEN environment variable is required but not set"
    echo "Please set the TUNNEL_TOKEN environment variable with your Cloudflare tunnel token"
    echo "Example: export TUNNEL_TOKEN=your_token_here"
    echo "For setup instructions, see the README.md documentation"
    exit 1
fi

echo "✅ TUNNEL_TOKEN found, starting Cloudflare tunnel..."

# Start cloudflared tunnel with the provided token
exec cloudflared tunnel --no-autoupdate run --token "${TUNNEL_TOKEN}"