# GitHub Copilot Instructions for OpenBalena

## Repository Overview

OpenBalena is a platform to deploy and manage connected IoT devices running balenaOS. This repository contains the backend services for self-hosting an OpenBalena instance.

## Project Structure

```
open-balena/
├── docs/                          # Documentation files
│   ├── CHANGELOG.md              # Version history and changes
│   ├── DOCKER_SWARM_IMPLEMENTATION.md  # Swarm deployment details
│   ├── getting-started.md        # Quick start guide
│   ├── docker-swarm-deployment.md # Swarm deployment guide
│   ├── kubernetes-migration.md   # K8s migration notes
│   ├── traefik-migration.md      # Traefik migration guide
│   ├── traefik-configuration.md  # Traefik setup details
│   ├── helm-reference.md         # Helm chart reference
│   └── ...                       # Other documentation
├── src/                          # Source code for services
│   ├── traefik/                  # Traefik reverse proxy
│   ├── cert-manager/             # Certificate management
│   ├── haproxy/                  # HAProxy (legacy)
│   ├── error-pages/              # Error page service
│   └── ...                       # Other service directories
├── scripts/                      # Utility scripts
│   ├── build-swarm-images.sh     # Build Docker images for Swarm
│   ├── validate-stack-files.py  # Validate Docker stack files
│   └── ...                       # Other scripts
├── docker-compose.yml            # Standalone deployment config
├── docker-stack.yml              # Docker Swarm stack config
├── docker-stack-internal.yml    # Internal services for Swarm
├── open-balena.sh                # Main orchestration script
└── README.md                     # Main repository documentation
```

## Key Technologies

- **Docker**: Containerization platform
- **Docker Compose**: Standalone deployment orchestration
- **Docker Swarm**: Cluster mode deployment orchestration
- **Traefik**: Modern reverse proxy and load balancer
- **PostgreSQL**: Primary database
- **Redis**: Caching layer
- **S3-compatible storage**: Object storage (MinIO)
- **balenaOS**: IoT device operating system
- **VPN**: Device connectivity service

## Deployment Modes

1. **Standalone Mode** (Docker Compose): Single-node deployment for development/testing
2. **Cluster Mode** (Docker Swarm): Multi-node deployment for production/high-availability

## Code Style Guidelines

### Shell Scripts
- Use `#!/usr/bin/env bash` shebang
- Enable strict error handling with `set -e`
- Use meaningful variable names in UPPER_CASE for environment variables
- Add comments for complex logic
- Follow existing patterns in `open-balena.sh`

### Python Scripts
- Follow PEP 8 style guidelines
- Use type hints where applicable
- Add docstrings to functions and classes

### YAML Files
- Use 2-space indentation
- Keep consistent structure with existing files
- Use anchors and aliases for repeated configurations (docker-compose.yml pattern)

### Dockerfiles
- Use official base images when possible
- Minimize layers
- Clean up in the same layer where packages are installed
- Use multi-stage builds when appropriate

## Important Files

### Orchestration
- `open-balena.sh`: Main entry point for all operations
  - Standalone commands: `config`, `up`, `down`, `logs`, `verify`
  - Swarm commands: `swarm-init`, `swarm-build`, `swarm-up`, `swarm-down`, `swarm-status`, `swarm-logs`

### Configuration
- `.env`: Environment variables (created by `config` command)
- `docker-compose.yml`: Standalone service definitions
- `docker-stack.yml`: Swarm service definitions
- `docker-stack-internal.yml`: Internal PostgreSQL and S3 for Swarm

### Service Directories
Each service in `src/` typically contains:
- `Dockerfile`: Container build configuration
- `balena.sh`: Entrypoint script (optional)
- Configuration files specific to that service

## Development Workflow

1. **Configuration**: Run `./open-balena.sh config` to set up environment
2. **Standalone Testing**: Use `./open-balena.sh up` for local development
3. **Swarm Testing**: Use swarm commands for cluster testing
4. **Validation**: Run relevant validation scripts in `scripts/`

## Common Tasks

### Adding a New Service
1. Create directory under `src/new-service/`
2. Add `Dockerfile` and any necessary configuration
3. Add service definition to `docker-compose.yml` (standalone mode)
4. Add service definition to `docker-stack.yml` (swarm mode)
5. Update `open-balena.sh` if new commands are needed
6. Document in `docs/` if user-facing

### Modifying Existing Service
1. Make changes in the service's `src/` directory
2. Test with standalone mode first
3. Verify swarm compatibility
4. Update documentation if behavior changes

### Adding Scripts
1. Place scripts in `scripts/` directory
2. Make executable: `chmod +x scripts/new-script.sh`
3. Follow existing naming conventions
4. Add validation/testing if applicable

## Testing

### Validation Scripts
- `scripts/validate-stack-files.py`: Validates Docker stack YAML syntax
- `scripts/validate-traefik-migration.sh`: Checks Traefik configuration
- `scripts/validate-api-env.sh`: Validates API environment setup
- `scripts/test-swarm-functionality.sh`: Tests Swarm deployment

### Manual Testing
```bash
# Test standalone deployment
./open-balena.sh config
./open-balena.sh up
./open-balena.sh verify

# Test swarm deployment
./open-balena.sh swarm-init
./open-balena.sh swarm-build
./open-balena.sh swarm-up
./open-balena.sh swarm-status
```

## Environment Variables

Key environment variables (set via `.env` file):
- `DNS_TLD`: Domain for the OpenBalena instance
- `PRODUCTION_MODE`: Enable production mode (true/false)
- `EXTERNAL_POSTGRES`: Use external PostgreSQL (true/false)
- `EXTERNAL_S3`: Use external S3 storage (true/false)
- `USE_NFS`: Enable NFS for shared storage in Swarm (true/false)
- `STACK_NAME`: Name for Docker Swarm stack (default: openbalena)

## Service Architecture

### Core Services
- **api**: Main API service (balena-io/open-balena-api)
- **vpn**: VPN service for device connectivity (balena-io/open-balena-vpn)
- **registry**: Container registry (balena-io/open-balena-registry)
- **db**: PostgreSQL database (optional if using external DB)
- **redis**: Redis cache
- **s3**: S3-compatible storage (MinIO)

### Enhanced Services
- **ui**: Web dashboard interface
- **builder**: Container build functionality
- **delta**: Delta update processing
- **helper**: Utility functions
- **postgrest**: REST API for PostgreSQL
- **remote**: Remote device access

### Infrastructure Services
- **traefik**: Reverse proxy and load balancer
- **cert-manager**: SSL/TLS certificate management
- **cloudflared**: Cloudflare tunnel support (optional)

## Routing and Networking

Traefik routes traffic based on hostname patterns:
- `api.*` → API service
- `registry2.*` → Registry service
- `ui.*` → UI service
- `builder.*` → Builder service
- `s3.*` → S3 service
- `ca.*` → Certificate Authority
- `vpn.*` → VPN service

## Security Considerations

- Certificates are stored in `certs-data` volume
- Database credentials in environment variables (consider secrets management)
- Traefik handles SSL/TLS termination
- VPN provides secure device connectivity
- Basic auth on CA service with CRL exception

## Migration Notes

### From HAProxy to Traefik
The repository has migrated from HAProxy to Traefik. See `docs/traefik-migration.md` for details.

### From Kubernetes Helm to Docker
The repository previously used Kubernetes Helm charts. See `docs/helm-reference.md` for the original structure.

## Best Practices for Copilot

1. **Preserve Backward Compatibility**: OpenBalena supports both standalone and swarm modes
2. **Update Both Configurations**: When adding services, update both docker-compose.yml and docker-stack.yml
3. **Document Changes**: Update relevant docs in `docs/` folder
4. **Test Thoroughly**: Use validation scripts to catch issues early
5. **Follow Existing Patterns**: Study similar services before implementing new ones
6. **Consider Production Use**: Changes should work in multi-node environments
7. **Maintain Minimal Changes**: Keep modifications surgical and focused

## Resources

- Main documentation: `README.md`
- Getting started: `docs/getting-started.md`
- Swarm deployment: `docs/docker-swarm-deployment.md`
- All documentation: `docs/` directory
- Official balenaOS: https://www.balena.io/os/
- balenaCloud (hosted version): https://www.balena.io/cloud/

## Support and Contribution

When making contributions:
- Keep changes minimal and focused
- Update documentation for user-facing changes
- Test in both standalone and swarm modes
- Follow the existing code style
- Add validation scripts for new functionality
