# Docker Swarm Deployment Guide

This guide explains how to deploy OpenBalena in Docker Swarm mode for high availability and scalability across multiple nodes.

## Overview

OpenBalena now supports two deployment modes:

1. **Standalone Mode** (Docker Compose) - Single node deployment for development and small-scale deployments
2. **Cluster Mode** (Docker Swarm) - Multi-node deployment for production environments with high availability

## When to Use Docker Swarm Mode

Use Docker Swarm mode when you need:

- **High Availability**: Services can run across multiple nodes with automatic failover
- **Scalability**: Services can be scaled horizontally across the cluster  
- **Load Distribution**: Services are automatically load-balanced across available nodes
- **Rolling Updates**: Services can be updated with zero downtime
- **Production Resilience**: Fault tolerance with automatic service recovery

## Prerequisites

- Docker Engine 17.06.0+ with Swarm mode support
- Multiple nodes for true high availability (minimum 3 manager nodes recommended)
- Shared storage (NFS) for persistent data across nodes (recommended)
- Network connectivity between all swarm nodes

## Quick Start

### 1. Initialize Docker Swarm

On your manager node:

```bash
./open-balena.sh swarm-init
```

This will initialize Docker Swarm mode and provide join tokens for worker nodes.

### 2. Add Worker Nodes (Optional)

On each worker node, run the join command provided by the swarm-init step:

```bash
docker swarm join --token SWMTKN-... <manager-ip>:2377
```

### 3. Build Required Images

Since Docker Swarm doesn't support build contexts, you need to build the required images:

```bash
./open-balena.sh swarm-build
```

This builds:
- `openbalena/traefik:latest`
- `openbalena/error-pages:latest`
- `openbalena/traefik-sidecar:latest`

### 4. Configure Environment

Generate your configuration (same as standalone mode):

```bash
./open-balena.sh config
```

### 5. Deploy the Stack

```bash
./open-balena.sh swarm-up
```

## NFS Configuration for Swarm

For production deployments, you should use shared storage to ensure data persistence across nodes:

```bash
./open-balena.sh swarm-nfs-setup
```

This will:
- Configure NFS connection details
- Generate `docker-stack-nfs.yml` for shared volumes
- Update your `.env` file with NFS settings

## Stack Management

### Check Stack Status

```bash
./open-balena.sh swarm-status
```

### View Service Logs

```bash
./open-balena.sh swarm-logs api
./open-balena.sh swarm-logs traefik
```

### Update the Stack

After making configuration changes:

```bash
./open-balena.sh swarm-up
```

Docker Swarm will perform a rolling update of changed services.

### Remove the Stack

```bash
./open-balena.sh swarm-down
```

## Architecture Differences

### Service Placement

Some services require specific placement constraints:

- **traefik**: Manager nodes only (needs Docker socket access)
- **traefik-sidecar**: Manager nodes only (needs Docker socket access)  
- **builder**: Manager nodes only (needs Docker socket access)
- **Other services**: Can run on any node

### Networking

- Uses overlay networks for inter-service communication
- Services are accessible via Docker Swarm's built-in load balancer
- External ports are published in `host` mode for Traefik

### Volumes

- Supports both Docker managed volumes and NFS volumes
- NFS volumes recommended for multi-node deployments
- All volumes are shared across the cluster when using NFS

## Configuration Files

### Main Stack File

- `docker-stack.yml` - Core services configuration
- `docker-stack-internal.yml` - Internal PostgreSQL and S3 services
- `docker-stack-nfs.yml` - NFS volume configuration (generated)

### Environment Variables

The same environment variables from standalone mode apply, plus:

- `STACK_NAME` - Docker Swarm stack name (default: openbalena)

## Scaling Services

You can scale individual services in the swarm:

```bash
# Scale API service to 3 replicas
docker service scale openbalena_api=3

# Scale UI service to 2 replicas  
docker service scale openbalena_ui=2
```

Note: Database services should not be scaled beyond 1 replica unless using external managed databases.

## Multi-Node Image Distribution

For multi-node deployments, you have three options for distributing the built images:

### Option 1: Docker Registry (Recommended)

Push images to a registry accessible by all nodes:

```bash
# Tag and push images
docker tag openbalena/traefik:latest your-registry.com/openbalena/traefik:latest
docker push your-registry.com/openbalena/traefik:latest

# Update docker-stack.yml to use registry images
sed -i 's|openbalena/traefik:latest|your-registry.com/openbalena/traefik:latest|g' docker-stack.yml
```

### Option 2: Build on Each Node

Run the build script on each node:

```bash
./scripts/build-swarm-images.sh
```

### Option 3: Save/Load Images

On the manager node:

```bash
docker save openbalena/traefik:latest openbalena/error-pages:latest openbalena/traefik-sidecar:latest | gzip > openbalena-images.tar.gz
```

On each worker node:

```bash
gunzip -c openbalena-images.tar.gz | docker load
```

## Troubleshooting

### Service Won't Start

Check service logs:

```bash
./open-balena.sh swarm-logs <service-name>
```

Check service status:

```bash
docker service ps openbalena_<service-name>
```

### Image Not Found

Ensure images are available on all nodes where the service might run:

```bash
docker service ps openbalena_<service-name> --no-trunc
```

If you see "no suitable node" errors, the required image may not be available on worker nodes.

### Volume Issues

For NFS volumes, ensure:
- NFS server is accessible from all swarm nodes
- NFS exports are configured correctly
- Network connectivity allows NFS traffic (port 2049)

Test NFS connectivity from each node:

```bash
showmount -e <nfs-server-ip>
```

## Migration from Standalone to Swarm

To migrate from standalone Docker Compose to Swarm:

1. **Stop standalone deployment**:
   ```bash
   ./open-balena.sh down
   ```

2. **Backup volumes** (if not using NFS):
   ```bash
   docker run --rm -v openbalena_db-data:/source -v $(pwd):/backup ubuntu tar czf /backup/db-backup.tar.gz -C /source .
   # Repeat for other volumes as needed
   ```

3. **Initialize swarm and build images**:
   ```bash
   ./open-balena.sh swarm-init
   ./open-balena.sh swarm-build
   ```

4. **Deploy stack**:
   ```bash
   ./open-balena.sh swarm-up
   ```

5. **Restore data** (if needed):
   ```bash
   # Create volumes and restore data as needed
   ```

## Best Practices

1. **Use NFS or external storage** for production deployments
2. **Configure at least 3 manager nodes** for high availability
3. **Monitor resource usage** and scale services as needed
4. **Use external databases** for large-scale deployments
5. **Regular backups** of persistent data
6. **Test failover scenarios** in staging environments
7. **Use image registries** for multi-node deployments

## Limitations

1. **Build contexts not supported** - Images must be pre-built
2. **Some Compose features unavailable** - `depends_on`, `profiles`, etc.
3. **Host-specific mounts** may not work across all nodes
4. **Service startup ordering** relies on Docker Swarm's eventual consistency

## Support

For issues with Docker Swarm deployment:

1. Check service logs: `./open-balena.sh swarm-logs <service>`
2. Verify swarm status: `docker node ls`
3. Check service status: `./open-balena.sh swarm-status`
4. Review network connectivity between nodes
5. Ensure all required images are available on all nodes