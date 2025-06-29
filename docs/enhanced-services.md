# Enhanced Services Setup Guide

This guide covers the setup and usage of the enhanced services that have been migrated from the open-balena-helm repository.

## Quick Start

The enhanced services are automatically included when you run the standard OpenBalena setup:

```bash
export DNS_TLD=mydomain.com
make up
```

All services will be available at their respective subdomains:
- UI Dashboard: `https://admin.mydomain.com`
- Builder: `https://builder.mydomain.com`
- Delta: `https://delta.mydomain.com`
- PostgREST: `https://postgrest.mydomain.com`
- Remote: `https://remote.mydomain.com`

## Service Details

### UI Dashboard (`https://admin.{DNS_TLD}`)

The UI dashboard provides a web interface for managing your OpenBalena deployment.

**Features:**
- Device fleet management
- Application monitoring
- User-friendly interface for OpenBalena operations
- Integration with all OpenBalena services

**Configuration:**
```bash
BANNER_IMAGE=https://example.com/logo.png  # Optional custom banner
```

**Access:** Open `https://admin.{DNS_TLD}` in your browser

### Builder Service (`https://builder.{DNS_TLD}`)

Handles container builds for your applications.

**Features:**
- Multi-architecture container builds
- Integration with device deployment pipeline
- Docker-in-Docker support

**Requirements:**
- Docker socket access (automatically configured)
- Sufficient disk space for build artifacts

**Usage:** Automatically used by the OpenBalena API for application builds

### Delta Service (`https://delta.{DNS_TLD}`)

Processes delta updates for efficient device updates.

**Features:**
- Incremental container updates
- Reduced bandwidth usage
- Faster deployment times

**Usage:** Automatically used when deploying application updates

### PostgREST Service (`https://postgrest.{DNS_TLD}`)

Provides RESTful API access to the PostgreSQL database.

**Features:**
- Automatic API generation from database schema
- Direct database access via REST
- Query filtering and pagination

**Example Usage:**
```bash
# Get all applications
curl https://postgrest.mydomain.com/application

# Get specific device
curl https://postgrest.mydomain.com/device?uuid=eq.abc123
```

### Remote Service (`https://remote.{DNS_TLD}`)

Enables SSH and remote terminal access to devices.

**Features:**
- SSH tunneling through OpenBalena infrastructure
- Remote terminal access
- Secure device access without direct network exposure

**Ports:** TCP ports 10000-10009 are exposed for device connections

**Usage:** Integrates with balena CLI for device SSH access

### Helper Service

Provides utility functions, routed through the API service.

**Features:**
- Download handling (`/download` endpoint)
- Supervisor release management (`/v6/supervisor_release`)
- File serving and utilities

**Usage:** Automatically handled by API routing

## Storage Requirements

The enhanced services use additional Docker volumes:

```bash
# Check volume usage
docker volume ls | grep openbalena
docker system df
```

**Volume Usage:**
- `builder-storage`: ~1-10GB (depends on build activity)
- `delta-storage`: ~500MB-2GB (depends on delta operations)
- `helper-storage`: ~100MB-1GB (cached downloads)

## Monitoring

### Health Checks

All services include health checks:

```bash
# Check service health
docker compose ps

# View service status in Traefik dashboard
# Open https://yourdomain.com:1936
```

### Logs

Monitor service logs:

```bash
# View all logs
docker compose logs

# Specific service logs
docker compose logs ui
docker compose logs builder
docker compose logs delta
```

### Resource Usage

Monitor resource consumption:

```bash
# Resource usage
docker stats

# Service-specific stats
docker stats openbalena-ui-1 openbalena-builder-1
```

## Troubleshooting

### Common Issues

1. **Service not accessible**
   ```bash
   # Check Traefik routing
   docker compose logs traefik
   
   # Verify service is running
   docker compose ps [service-name]
   ```

2. **Build failures in Builder service**
   ```bash
   # Check Docker socket access
   docker compose exec builder docker ps
   
   # View builder logs
   docker compose logs builder
   ```

3. **UI not loading**
   ```bash
   # Check UI service logs
   docker compose logs ui
   
   # Verify environment variables
   docker compose exec ui env | grep REACT_APP
   ```

### Service Dependencies

Services have the following dependencies:

```
api → db, redis, s3
ui → api, s3
postgrest → db
remote → api
builder → api
delta → api, s3
helper → api, s3
```

Ensure all dependencies are healthy before troubleshooting specific services.

## Security Considerations

### Network Access

- All services are behind Traefik reverse proxy
- HTTPS is enforced for all external access
- Internal communication uses Docker network

### Authentication

- UI: Uses JWT authentication via API
- PostgREST: Uses database role-based access
- Remote: Integrates with OpenBalena device authentication
- Builder: Uses service tokens for API communication

### Firewall Configuration

Required ports:
- 80/443: HTTP/HTTPS (Traefik)
- 10000-10009: Remote device access
- 1936: Traefik dashboard (optional)

## Customization

### Environment Variables

See `docs/environment-variables.md` for full configuration options.

### Service Images

To use custom images:

```yaml
# In docker-compose.override.yml
services:
  ui:
    image: my-custom-ui:latest
  builder:
    image: my-custom-builder:latest
```

### Resource Limits

Add resource constraints:

```yaml
# In docker-compose.override.yml
services:
  builder:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
```

## Migration Notes

If migrating from the Kubernetes deployment, see `docs/kubernetes-migration.md` for detailed migration instructions.

## Support

For issues with enhanced services:
1. Check service logs: `docker compose logs [service]`
2. Verify configuration: `docker compose config`
3. Review Traefik routing: Access dashboard at `:1936`
4. Check GitHub issues for known problems