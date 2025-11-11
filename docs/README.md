# OpenBalena Documentation

This directory contains comprehensive documentation for the OpenBalena project.

## Table of Contents

### Getting Started
- **[Getting Started Guide](getting-started.md)** - Quick start guide for deploying OpenBalena
- **[Unified Modern Deployment Guide](doc_openbalena-unified-modern-deployment-guide.md)** - Comprehensive modern deployment guide
- **[Environment Variables](environment-variables.md)** - Configuration options and environment variables

### Deployment Guides
- **[Docker Swarm Deployment](docker-swarm-deployment.md)** - Deploy OpenBalena in cluster mode with Docker Swarm
- **[DOCKER_SWARM_IMPLEMENTATION.md](DOCKER_SWARM_IMPLEMENTATION.md)** - Detailed implementation summary of Docker Swarm support
- **[External Services](external-services.md)** - Using external PostgreSQL and S3 services

### Migration Guides
- **[Traefik Migration](traefik-migration.md)** - Migrating from HAProxy to Traefik
- **[Traefik Configuration](traefik-configuration.md)** - Traefik setup and configuration details
- **[Kubernetes Migration](kubernetes-migration.md)** - Notes on Kubernetes/Helm migration
- **[Helm Reference](helm-reference.md)** - Original Helm chart reference

### Advanced Topics
- **[Enhanced Services](enhanced-services.md)** - Additional services (UI, Builder, Delta, etc.)
- **[API Environment Fix](api-environment-fix.md)** - API environment configuration fixes

### Reference
- **[CHANGELOG.md](CHANGELOG.md)** - Complete version history and changes

## Quick Links

### For New Users
1. Start with the [Getting Started Guide](getting-started.md)
2. Review [Environment Variables](environment-variables.md) for configuration options
3. Check [External Services](external-services.md) if using external databases or storage

### For Production Deployments
1. Review the [Docker Swarm Deployment](docker-swarm-deployment.md) guide
2. Read the [DOCKER_SWARM_IMPLEMENTATION.md](DOCKER_SWARM_IMPLEMENTATION.md) for implementation details
3. Consider [External Services](external-services.md) for production-grade infrastructure

### For Developers
1. Review the [Enhanced Services](enhanced-services.md) documentation
2. Check the [API Environment Fix](api-environment-fix.md) for API configuration
3. See [Traefik Configuration](traefik-configuration.md) for routing details

## Additional Resources

- Main README: [../README.md](../README.md)
- GitHub Copilot Instructions: [../.github/copilot-instructions.md](../.github/copilot-instructions.md)
- Official balenaOS: https://www.balena.io/os/
- balenaCloud (hosted version): https://www.balena.io/cloud/

## Contributing

When adding new documentation:
1. Place markdown files in this directory
2. Update this README.md with links to new documentation
3. Use clear, descriptive filenames
4. Include examples and usage instructions
5. Keep documentation up-to-date with code changes
