# Cloudflared Docker configuration for openBalena
FROM alpine:latest

# Install dependencies and cloudflared
RUN apk add --no-cache ca-certificates curl && \
    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared && \
    apk del curl

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create a non-root user to run cloudflared
RUN adduser -D -s /bin/sh cloudflared
USER cloudflared

# Health check to verify the tunnel is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD pgrep cloudflared || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]