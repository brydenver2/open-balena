#!/usr/bin/env bash

set -e

# build-swarm-images.sh - Build Docker images required for Swarm deployment
# These images are needed because Docker Swarm mode doesn't support build contexts

echo "==> Building OpenBalena Docker images for Swarm deployment..."

# Set image tag prefix - can be overridden with environment variable
IMAGE_PREFIX="${IMAGE_PREFIX:-openbalena}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Check if we're in the correct directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "Error: docker-compose.yml not found. Please run this script from the OpenBalena root directory."
    exit 1
fi

# Build Traefik image
echo "==> Building Traefik image..."
if [[ -d "src/traefik" ]]; then
    docker build -t "${IMAGE_PREFIX}/traefik:${IMAGE_TAG}" src/traefik/
    echo "✓ Built ${IMAGE_PREFIX}/traefik:${IMAGE_TAG}"
else
    echo "Error: src/traefik directory not found"
    exit 1
fi

# Build error-pages image
echo "==> Building error-pages image..."
if [[ -d "src/error-pages" ]]; then
    docker build -t "${IMAGE_PREFIX}/error-pages:${IMAGE_TAG}" src/error-pages/
    echo "✓ Built ${IMAGE_PREFIX}/error-pages:${IMAGE_TAG}"
else
    echo "Error: src/error-pages directory not found"
    exit 1
fi

# Build traefik-sidecar image
echo "==> Building traefik-sidecar image..."
if [[ -d "src/traefik-sidecar" ]]; then
    docker build -t "${IMAGE_PREFIX}/traefik-sidecar:${IMAGE_TAG}" src/traefik-sidecar/
    echo "✓ Built ${IMAGE_PREFIX}/traefik-sidecar:${IMAGE_TAG}"
else
    echo "Error: src/traefik-sidecar directory not found"
    exit 1
fi

echo "==> All images built successfully!"
echo ""
echo "Built images:"
echo "  ${IMAGE_PREFIX}/traefik:${IMAGE_TAG}"
echo "  ${IMAGE_PREFIX}/error-pages:${IMAGE_TAG}"
echo "  ${IMAGE_PREFIX}/traefik-sidecar:${IMAGE_TAG}"
echo ""
echo "Note: If you're deploying to a multi-node swarm, you'll need to:"
echo "1. Push these images to a registry accessible by all nodes, or"
echo "2. Build these images on each node"
echo ""
echo "To push to a registry:"
echo "  docker push ${IMAGE_PREFIX}/traefik:${IMAGE_TAG}"
echo "  docker push ${IMAGE_PREFIX}/error-pages:${IMAGE_TAG}"
echo "  docker push ${IMAGE_PREFIX}/traefik-sidecar:${IMAGE_TAG}"