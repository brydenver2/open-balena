# Kubernetes to Docker Migration Guide

This document describes the migration from the Kubernetes Helm chart (`open-balena-helm`) to the Docker Compose deployment included in this repository.

## Overview

The `open-balena-helm` repository provided a Kubernetes-based deployment using Helm charts. All functionality from that repository has been migrated to Docker Compose services while maintaining the same routing patterns and service capabilities.

## Services Migration

### Core Services (Pre-existing)
These services were already present in the Docker Compose setup:
- **api** - OpenBalena API service
- **registry** - Container registry
- **vpn** - VPN service for device connectivity  
- **db** - PostgreSQL database
- **s3** - S3-compatible storage service
- **redis** - Redis cache
- **traefik** - Reverse proxy (migrated from HAProxy)
- **cloudflared** - Tunnel service

### New Services (Added from Helm Chart)
These services have been migrated from Kubernetes deployments:

#### UI Service (`harmonidcaputo/open-balena-ui`)
- **Kubernetes**: `Deployment` with `Service` and `Ingress`
- **Docker**: Service with Traefik routing
- **Access**: `https://admin.{DNS_TLD}` or `https://ui.{DNS_TLD}`
- **Purpose**: Web dashboard for managing devices and applications

#### Builder Service (`harmonidcaputo/open-balena-builder`) 
- **Kubernetes**: `Deployment` with persistent storage
- **Docker**: Service with Docker socket access and storage volume
- **Access**: `https://builder.{DNS_TLD}`
- **Purpose**: Multi-architecture container builds

#### Delta Service (`harmonidcaputo/open-balena-delta`)
- **Kubernetes**: `Deployment` with persistent storage
- **Docker**: Service with storage volume
- **Access**: `https://delta.{DNS_TLD}`
- **Purpose**: Delta update processing for efficient device updates

#### Helper Service (`harmonidcaputo/open-balena-helper`)
- **Kubernetes**: `Deployment` with storage
- **Docker**: Service integrated with API routing
- **Access**: Routed through API service (`/download`, `/v6/supervisor_release`)
- **Purpose**: Download and supervisor release utilities

#### PostgREST Service (`harmonidcaputo/open-balena-postgrest`)
- **Kubernetes**: `Deployment` with database connection
- **Docker**: Service with direct database access
- **Access**: `https://postgrest.{DNS_TLD}`
- **Purpose**: RESTful API for direct database access

#### Remote Service (`harmonidcaputo/open-balena-remote`)
- **Kubernetes**: `Deployment` with TCP port exposure
- **Docker**: Service with TCP ports 10000-10009 exposed
- **Access**: `https://remote.{DNS_TLD}` + TCP ports
- **Purpose**: SSH and remote terminal access to devices

## Routing Migration

### From Kubernetes Ingress to Traefik
- **Before**: HAProxy Ingress Controller with `Ingress` resources
- **After**: Traefik reverse proxy with dynamic configuration

### Routing Patterns
All hostname patterns have been preserved:

| Service | Kubernetes Host | Docker/Traefik Host | Backend |
|---------|----------------|---------------------|---------|
| API | `api.{hostname}` | `api.*` | `api:80` |
| Registry | `registry.{hostname}` | `registry2.*` | `registry:80` |
| S3 | `s3.{hostname}` | `s3.*` | `s3:80` |
| UI | `admin.{hostname}` | `admin.*` \| `ui.*` | `ui:80` |
| Builder | `builder.{hostname}` | `builder.*` | `builder:80` |
| Delta | `delta.{hostname}` | `delta.*` | `delta:80` |
| PostgREST | `postgrest.{hostname}` | `postgrest.*` | `postgrest:80` |
| Remote | `remote.{hostname}` | `remote.*` | `remote:80` |

### Special Routing
- **Helper Downloads**: `api.*/download` → `helper:80`
- **Supervisor Releases**: `api.*/v6/supervisor_release` → `helper:80`
- **Health Checks**: `/health` → `api:80`

## Storage Migration

### From PersistentVolumeClaims to Docker Volumes
- **Kubernetes**: Used `PersistentVolumeClaim` resources
- **Docker**: Uses named Docker volumes

| Service | Kubernetes PVC | Docker Volume |
|---------|---------------|---------------|
| Builder | `builder-storage` | `builder-storage` |
| Delta | `delta-storage` | `delta-storage` |
| Helper | `helper-storage` | `helper-storage` |
| Database | `db-storage` | `db-data` |
| S3 | `s3-storage` | `s3-data` |
| Redis | `redis-storage` | `redis-data` |

## Configuration Migration

### Environment Variables
Most environment variables have been preserved with Docker-specific adaptations:

```bash
# Core configuration
DNS_TLD=yourdomain.com
SUPERUSER_EMAIL=admin@yourdomain.com
SUPERUSER_PASSWORD=yourpassword

# New service configuration
BANNER_IMAGE=                    # Optional UI banner image
REMOTE_SENTRY_DSN=              # Optional remote service error tracking
OPENBALENA_API_VERSION=v37.3.4  # API version for UI display
```

### Secrets Management
- **Kubernetes**: Used `Secret` resources
- **Docker**: Uses environment variables and volume-mounted certificates

## Certificate Management

### TLS/SSL Certificates
- **Kubernetes**: Used cert-manager with Let's Encrypt
- **Docker**: Uses existing cert-manager service with Traefik integration

### Certificate Paths
Certificates are mounted at standard paths:
- `/certs/cert.pem` - TLS certificate
- `/certs/privkey.pem` - Private key
- `/certs/root-ca.pem` - Root CA certificate

## Migration Steps

If you're migrating from the Kubernetes deployment:

1. **Backup Data**: Export any important data from Kubernetes volumes
2. **Stop Kubernetes**: `helm uninstall openbalena`
3. **Setup Docker**: Follow the standard Docker Compose setup
4. **Migrate Data**: Copy data to Docker volumes if needed
5. **Update DNS**: Ensure DNS points to Docker host
6. **Start Services**: `make up`

## Networking

### Container Networking
- **Kubernetes**: Used `Service` resources for inter-pod communication
- **Docker**: Uses Docker Compose network with service names

### External Access
- **Kubernetes**: Used `NodePort` or `LoadBalancer` services
- **Docker**: Uses host port mapping and Traefik ingress

## Monitoring and Logging

### Health Checks
- **Kubernetes**: Used `livenessProbe` and `readinessProbe`
- **Docker**: Uses Docker healthcheck and Traefik health endpoints

### Logs
- **Kubernetes**: Accessible via `kubectl logs`
- **Docker**: Accessible via `docker compose logs`

## Compatibility

The Docker Compose deployment maintains full compatibility with:
- Device registration and management
- Application deployment workflows
- balena CLI operations
- API endpoints and functionality
- VPN connectivity
- Container registry operations

## Troubleshooting

### Common Issues
1. **Service Discovery**: Ensure service names resolve within Docker network
2. **Port Conflicts**: Check that ports 80, 443, and 10000-10009 are available
3. **Volume Permissions**: Verify volume mount permissions for services
4. **Certificate Issues**: Ensure certificate paths are correctly configured

### Debugging Commands
```bash
# Check service status
docker compose ps

# View service logs
docker compose logs [service-name]

# Test connectivity
docker compose exec api curl http://ui/

# Validate Traefik configuration
docker compose logs traefik
```

## Benefits of Migration

1. **Simplified Deployment**: No Kubernetes cluster required
2. **Reduced Complexity**: Single Docker Compose file vs multiple Kubernetes resources
3. **Better Resource Usage**: More efficient on single-node deployments
4. **Easier Development**: Local development and testing simplified
5. **Maintained Functionality**: All features preserved with improved reliability

## Reference

- Original Helm charts: `helm/` directory in this repository
- Traefik configuration: `src/traefik/`
- Docker Compose: `docker-compose.yml`
- Documentation: `docs/` directory