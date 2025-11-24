#!/bin/bash
# Wan2.2 Docker daemon startup script
# Usage: ./run.sh

set -e

# Load configuration
if [ -f .env ]; then
    source .env
else
    echo "Warning: .env file not found. Using defaults."
    DOCKER_IMAGE="ghcr.io/your-org/wan22-t2v:latest"
fi

echo "=== Wan2.2 Docker Setup ==="
echo "Image: $DOCKER_IMAGE"
echo ""

# Pull image
echo "Pulling image from registry..."
docker compose pull

# Start daemon container
echo "Starting daemon container..."
docker compose run -d --name wan22 wan22

echo ""
echo "=== Container Running ==="
echo "sudo docker logs -f wan22"
echo "sudo docker attach wan22"
echo ""
