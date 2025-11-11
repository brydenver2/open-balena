# Certificate Manager for OpenBalena
# Manages SSL/TLS certificates for the OpenBalena deployment
# Based on balena's cert-manager: https://github.com/balena-io/cert-manager
# 
# This service handles:
# - Certificate generation and renewal
# - Certificate storage and distribution
# - Integration with Let's Encrypt (ACME protocol)
# - Custom PKI certificate management

FROM balena/cert-manager:0.3.3

# Copy certificate configuration files
COPY *.json /opt/
