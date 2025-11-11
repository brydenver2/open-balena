# Traefik Configuration for OpenBalena

This directory contains the Traefik reverse proxy configuration that replaces HAProxy in openBalena.

## Structure

```
src/traefik/
├── Dockerfile              # Traefik container build configuration
├── traefik.yml             # Static configuration (entrypoints, providers, etc.)
├── generate-config.sh      # Runtime configuration generator
└── templates/
    ├── config.yml          # Dynamic configuration template (routers, services, middleware)
    └── errors.yml          # Error page configuration
```

## Key Features

- **HTTP/HTTPS Routing**: Host-based routing for all openBalena services
- **SSL/TLS Termination**: TLS 1.2+ with modern cipher suites
- **Authentication**: Basic auth for CA service with CRL exception
- **Health Monitoring**: Dashboard on port 1936
- **Error Handling**: Custom error pages
- **TCP Routing**: VPN and tunnel traffic support
- **CORS Support**: Cross-origin request handling

## Configuration Generation

The `generate-config.sh` script processes templates at runtime to:
- Replace environment variable placeholders
- Generate proper authentication hashes
- Create dynamic configuration files

## Environment Variables

Required:
- `DNS_TLD`: Domain name for routing rules
- `BALENA_DEVICE_UUID`: Used for authentication

Optional:
- `TRAEFIK_CRT` / `HAPROXY_CRT`: SSL certificate path
- `TRAEFIK_KEY` / `HAPROXY_KEY`: SSL private key path
- `LOGLEVEL`: Logging level (default: INFO)

## Ports

- **80**: HTTP traffic
- **443**: HTTPS/SSL traffic  
- **1936**: Traefik dashboard and metrics

## Service Mapping

| Service | Route Pattern | Backend |
|---------|---------------|---------|
| API | `api.*` | `api:80` |
| Registry | `registry2.*` | `registry:80` |
| S3 | `s3.*` | `s3:80` |
| MinIO | `minio.*` | `s3:43697` |
| CA | `ca.*` | `balena-ca:8888` |
| OCSP | `ocsp.*` | `balena-ca:8889` |
| VPN | Non-SSL on 443 | `vpn:443` |
| Tunnel | `tunnel.*` SNI | `vpn:3128` |

## Health Checks

- **Service Health**: Automatic health checks for all backend services
- **Traefik Health**: `/ping` endpoint for container health monitoring
- **Dashboard**: Real-time service status at `:1936`

## Migration from HAProxy

See [traefik-migration.md](traefik-migration.md) for complete migration details.

## Debugging

```bash
# Check configuration syntax
docker compose config

# View Traefik logs
docker compose logs traefik

# Test API connectivity
make verify

# Access dashboard (in browser)
http://localhost:1936
```