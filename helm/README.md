# OpenBalena Helm Chart Reference

This directory contains the original Kubernetes Helm chart configurations from the `open-balena-helm` repository for reference purposes. The functionality has been migrated to Docker Compose services in the main repository.

## Original Helm Chart Services

The following services were available in the Kubernetes deployment:

### Core Services (already present in Docker Compose)
- **api** - OpenBalena API service
- **registry** - Container registry
- **vpn** - VPN service for device connectivity
- **db** - PostgreSQL database
- **s3** - S3-compatible storage service
- **redis** - Redis cache

### Additional Services (migrated to Docker Compose)
- **ui** - Web dashboard interface (`harmonidcaputo/open-balena-ui`)
- **builder** - Container build functionality (`harmonidcaputo/open-balena-builder`)
- **delta** - Delta update processing (`harmonidcaputo/open-balena-delta`)
- **helper** - Utility functions (`harmonidcaputo/open-balena-helper`)
- **postgrest** - REST API for PostgreSQL (`harmonidcaputo/open-balena-postgrest`)
- **remote** - Remote device access (`harmonidcaputo/open-balena-remote`)

## Migration Notes

The Helm chart used HAProxy Ingress Controller for routing, which has been converted to use Traefik (already present in the Docker Compose setup). The routing patterns have been preserved to maintain compatibility.

### Key Changes:
- Kubernetes Deployments → Docker Compose services
- HAProxy Ingress → Traefik routing rules
- Kubernetes Secrets → Environment variables and volumes
- PersistentVolumeClaims → Docker volumes

## Routing

All services maintain the same hostname patterns:
- `api.*` → API service
- `registry2.*` → Registry service
- `ui.*` → UI service
- `builder.*` → Builder service
- And so on...

## Original Repository

The original Helm charts can be found at: https://github.com/brydenver2/open-balena-helm