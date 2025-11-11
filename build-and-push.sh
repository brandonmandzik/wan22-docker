#!/bin/bash
# Build, tag, and push Wan2.2 Docker image to registry
# Usage: ./build-and-push.sh [registry-image-name]

set -e

# Load configuration
if [ -f .env ]; then
    source .env
fi

# Override with command line argument if provided
REGISTRY_IMAGE="${1:-${DOCKER_IMAGE}}"

if [ -z "$REGISTRY_IMAGE" ]; then
    echo "Error: No registry image specified."
    echo "Usage: ./build-and-push.sh <registry-image>"
    echo "Example: ./build-and-push.sh ghcr.io/your-org/wan22-t2v:v2.2"
    exit 1
fi

echo "=== Wan2.2 Docker Build and Push ==="
echo "Registry: $REGISTRY_IMAGE"
echo ""

# Build the image
echo "Step 1/3: Building Docker image..."
echo "This will take 20-30 minutes (installs dependencies and compiles flash-attn)"
docker-compose build

# Tag for registry
echo ""
echo "Step 2/3: Tagging image for registry..."
docker tag wan22-t2v:latest "$REGISTRY_IMAGE"

# Push to registry
echo ""
echo "Step 3/3: Pushing to registry..."
echo "Pushing 38GB image - this may take 10-20 minutes..."
docker push "$REGISTRY_IMAGE"

echo ""
echo "=== Build and Push Complete! ==="
echo "Image available at: $REGISTRY_IMAGE"
echo ""
echo "To use this image:"
echo "1. Update .env: MODE=pull"
echo "2. Update .env: DOCKER_IMAGE=$REGISTRY_IMAGE"
echo "3. Run: ./run.sh \"your prompt\""
echo ""
echo "Or on any other machine:"
echo "docker pull $REGISTRY_IMAGE"
echo "docker run --gpus all -v ./outputs:/outputs $REGISTRY_IMAGE python generate.py ..."
