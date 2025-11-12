#!/bin/bash
# Inference script for Wan2.2 T2V model
# Automatically detects MODE (build or pull) from .env
# Usage: ./run.sh "your prompt here" [size]

set -e

# Log all output while preserving TTY for progress bars
exec script -q -f /var/log/my-log.log


# Load configuration
if [ -f .env ]; then
    source .env
else
    echo "Warning: .env file not found. Using defaults."
    MODE="build"
    DOCKER_IMAGE="ghcr.io/your-org/wan22-t2v:latest"
fi

# Default parameters
PROMPT="${1:-A serene lake at sunset with mountains in the background}"
SIZE="${2:-832*480}"
OUTPUT_DIR="/opt/Wan2.2/outputs"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=== Wan2.2 T2V Inference ==="
echo "Mode: $MODE"
echo "Prompt: $PROMPT"
echo "Size: $SIZE"
echo ""

# Handle different modes
case "$MODE" in
    build)
        echo "MODE=build: Building image locally if needed..."
        # Check if image exists
        if ! docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
            echo "Image not found. Building from Dockerfile..."
            echo "This will take 60-75 minutes on first run..."
            docker-compose build
        else
            echo "Image found: $DOCKER_IMAGE"
        fi
        ;;

    pull)
        echo "MODE=pull: Using pre-built image from registry..."
        # Pull image if not already present
        if ! docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
            echo "Pulling image: $DOCKER_IMAGE"
            echo "This will download ~30GB (may take 10 minutes)..."
            docker pull "$DOCKER_IMAGE"
        else
            echo "Image already present: $DOCKER_IMAGE"
        fi
        ;;

    *)
        echo "Error: Invalid MODE='$MODE' in .env"
        echo "MODE must be 'build' or 'pull'"
        exit 1
        ;;
esac

echo ""
echo "Running inference with image: $DOCKER_IMAGE"
echo ""

# Run inference using docker-compose run (reuses container across runs)
docker compose up wan22
docker-compose exec wan22 python3 generate.py \
    --task t2v-A14B \
    --size "$SIZE" \
    --ckpt_dir /Wan2.2/checkpoints/Wan2.2-T2V-A14B \
    --offload_model True \
    --convert_model_dtype \
    --prompt "$PROMPT" \
    --save_file /Wan2.2/outputs \
    --t5_cpu \
    --sample_steps 40 \
    --frame_num 49 \
    --sample_guide_scale 5.0 \
    --sample_shift 7.0 \
    --base_seed 42

echo ""
echo "=== Inference Complete! ==="
echo "Output saved to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
