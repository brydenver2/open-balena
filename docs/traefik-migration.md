# HAProxy to Traefik Migration

This document describes the migration from HAProxy to Traefik as the reverse proxy for openBalena.

## Overview

OpenBalena has been migrated from HAProxy to Traefik v3.0 as the reverse proxy solution. This migration preserves all existing functionality while providing:

- Modern configuration syntax
- Better Docker integration
- Enhanced monitoring and dashboard
- Improved routing flexibility

## Changes Made

### 1. Configuration Structure

**Before (HAProxy):**
- Single `haproxy.cfg` configuration file
- Sections: global, defaults, frontend, backend, listen

**After (Traefik):**
- Static configuration: `traefik.yml`
- Dynamic configuration: `config.yml` and `errors.yml`
- Template-based configuration generation

### 2. Service Configuration

The Docker Compose service has been updated:

```yaml
# Old HAProxy service
haproxy:
  build: src/haproxy
  ports:
    - '80:80/tcp'
    - '443:443/tcp' 
    - '1936:1936/tcp'

# New Traefik service
traefik:
  build: src/traefik
  ports:
    - '80:80/tcp'
    - '443:443/tcp'
    - '1936:1936/tcp'
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
```

### 3. Environment Variables

For backward compatibility, existing environment variables are maintained:

- `HAPROXY_CRT` → Also creates `TRAEFIK_CRT`
- `HAPROXY_KEY` → Also creates `TRAEFIK_KEY`
- New variables: `TRAEFIK_CRT`, `TRAEFIK_KEY`

### 4. Feature Mapping

| HAProxy Feature | Traefik Equivalent | Status |
|-----------------|-------------------|--------|
| HTTP/HTTPS routing | HTTP routers | ✅ Implemented |
| SSL termination | TLS configuration | ✅ Implemented |
| Host-based routing | Router rules | ✅ Implemented |
| Authentication | BasicAuth middleware | ✅ Implemented |
| CORS handling | Headers middleware | ✅ Implemented |
| Health checks | Health checks | ✅ Implemented |
| Stats/monitoring | Dashboard | ✅ Implemented |
| Error pages | Error pages service | ✅ Implemented |
| TCP routing (VPN) | TCP routers | ✅ Implemented |

## Routing Configuration

### HTTP Services

All HTTP services are configured with similar routing patterns:

- **API**: `api.*` domains → `api-service`
- **Registry**: `registry2.*` domains → `registry-service`
- **S3**: `s3.*` domains → `s3-service`
- **MinIO**: `minio.*` domains → `minio-service`
- **CA**: `ca.*` domains → `ca-service` (with authentication)
- **OCSP**: `ocsp.*` domains → `ocsp-service`

### Special Routes

- **Health Check**: `/health` path → API service
- **CA CRL**: `/api/v1/cfssl/crl` → CA service (no auth required)
- **Default/PDU**: Device URLs → API service

### TCP/VPN Routing

- **Tunnel traffic**: `tunnel.*` SNI → VPN service port 3128
- **VPN traffic**: Non-SSL traffic → VPN service port 443

## SSL/TLS Configuration

Traefik is configured with:
- Minimum TLS version: 1.2
- Modern cipher suites
- Support for existing certificate paths

## Authentication

Basic authentication is implemented for the CA service:
- Username: `balena`
- Password: `${BALENA_DEVICE_UUID}` (bcrypt hashed)
- CRL endpoints bypass authentication

## Monitoring and Stats

Traefik dashboard is available on port 1936, providing:
- Service health status
- Request metrics
- Real-time traffic monitoring
- Configuration overview

## Migration Steps

1. **Backup**: The original HAProxy configuration is preserved in `src/haproxy/`
2. **Gradual**: Services can be updated gradually
3. **Testing**: Validate configuration with `make config` and `docker compose config`
4. **Verification**: Use `make verify` to test API endpoints

## Troubleshooting

### Configuration Issues
```bash
# Validate Docker Compose
docker compose config

# Check Traefik configuration
docker compose logs traefik

# Test API connectivity  
make verify
```

### Common Problems

1. **Certificate path issues**: Ensure `TRAEFIK_CRT` and `TRAEFIK_KEY` are set correctly
2. **DNS resolution**: Verify that service names resolve within Docker network
3. **Port conflicts**: Ensure ports 80, 443, and 1936 are available

## Rollback

If needed, to rollback to HAProxy:

1. Restore the haproxy service in docker-compose.yml
2. Update Makefile references back to haproxy
3. Remove traefik-related services

The original HAProxy configuration is preserved for reference.

## Performance

Traefik v3.0 provides comparable or better performance than HAProxy for the openBalena use case:
- Similar memory footprint
- Efficient HTTP/2 and HTTP/3 support
- Built-in metrics and monitoring
- Better container ecosystem integration