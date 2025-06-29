# Traefik Docker configuration for openBalena
FROM traefik:v3.0

# Install htpasswd for password hashing
RUN apk add --no-cache apache2-utils

# Copy Traefik configuration files
COPY traefik.yml /etc/traefik/traefik.yml
COPY templates/ /etc/traefik/templates/
COPY generate-config.sh /usr/local/bin/generate-config.sh

# Create directories for logs, certificates, and dynamic config
RUN mkdir -p /var/log /certs /etc/traefik/dynamic

# Set proper permissions
RUN chmod 644 /etc/traefik/traefik.yml
RUN chmod -R 644 /etc/traefik/templates/
RUN chmod +x /usr/local/bin/generate-config.sh

# Expose ports (HTTP, HTTPS, Traefik dashboard)
EXPOSE 80 443 1936

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD traefik healthcheck --ping

# Create entrypoint script that generates config and starts traefik
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'generate-config.sh' >> /entrypoint.sh && \
    echo 'exec traefik "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]