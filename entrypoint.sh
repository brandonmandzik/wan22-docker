#!/bin/bash
# Entrypoint for Wan2.2 Docker container
# Downloads models from HuggingFace Hub if not cached

set -e

echo "=== Wan2.2 Container Entrypoint ==="

# Check if models are downloaded
if [ ! -d "/Wan2.2/checkpoints/Wan2.2-T2V-A14B" ]; then
    echo "Models not found. Downloading from HuggingFace Hub..."
    echo "This will download ~126GB and may take 15-25 minutes..."

    huggingface-cli download \
        Wan-AI/Wan2.2-T2V-A14B \
        --local-dir /Wan2.2/checkpoints/Wan2.2-T2V-A14B \
        --resume-download

    echo "Model download complete!"
else
    echo "Models found in cache. Skipping download."
fi

# Execute the command passed to docker run
exec "$@"
