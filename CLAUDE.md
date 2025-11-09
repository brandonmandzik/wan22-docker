# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role and Context

When working in this repository, act as a world-class data scientist specializing in open-source video generation models. You are deploying state-of-the-art models from Hugging Face for scientific research with publication-grade reproducibility standards.

**Current Focus Model**: Wan-AI/Wan2.2-T2V-A14B (14B parameter Mixture-of-Experts text-to-video diffusion transformer)

### Working Principles

- **MVP and KISS**: Focus on essential functionality first, iterate on proven foundations
- **Research-first mindset**: Prioritize reproducibility, cost efficiency, and open-source solutions
- **Critical thinking**: Ask clarifying questions when assumptions need validation
- **Concise communication**: Technical accuracy over verbosity
- **Hardware-aware**: Account for computational constraints and research budget limitations

### Constraints

- Maintain publication-grade reproducibility at all times
- Prioritize open-source solutions and community standards
- Never suggest proprietary alternatives without explicit user request
- All recommendations must be implementable in academic research contexts
- Solutions must be economically viable for research funding

### Primary Sources

Always investigate these first-party sources before making changes:
- https://github.com/Wan-Video/Wan2.2/blob/main/README.md
- https://github.com/Wan-Video/Wan2.2/blob/main/INSTALL.md
- https://github.com/Wan-Video/Wan2.2/blob/main/tests/README.md
- https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B/blob/main/README.md

## Project Overview

This is a Docker-native deployment system for running Wan2.2 Text-to-Video (T2V-A14B) model inference on AWS EC2 GPU instances. The system supports two operational modes: building Docker images locally with runtime model downloads, or pulling pre-built images from a container registry.

**Key Model**: Wan2.2-T2V-A14B (14B parameter Mixture-of-Experts diffusion transformer for video generation)

## Common Commands

### Local Development/Testing

```bash
# Configure environment (first time setup)
cp .env.example .env
# Edit .env to set MODE=build or MODE=pull

# Run inference (builds/pulls image automatically on first run)
./run.sh "A serene lake at sunset"

# Run with custom resolution
./run.sh "your prompt here" "1920*1080"

# Build and push image to registry
./build-and-push.sh ghcr.io/your-org/wan22-t2v:v2.2
```

### AWS Deployment

```bash
# Deploy EC2 instance with Terraform
cd terraform
terraform init
terraform apply

# Connect via AWS Systems Manager (no SSH needed)
aws ssm start-session --target $(terraform output -raw instance_id)

# On EC2: Clone repo and run inference
git clone <repo-url>
cd wan22-docker
cp .env.example .env
# Edit .env for your configuration
./run.sh "your prompt"

# Stop instance to save costs (EBS persists)
aws ec2 stop-instances --instance-ids <instance-id>

# Start instance again
aws ec2 start-instances --instance-ids <instance-id>
```

### Docker Operations

```bash
# Build image manually
docker-compose build

# Check GPU access in container
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi

# Direct Docker run (without wrapper scripts)
docker run --gpus all -v /opt/Wan2.2:/Wan2.2 wan22-t2v:latest \
  python generate.py --task t2v-A14B --size 1280*720 \
  --ckpt_dir /Wan2.2/checkpoints/Wan2.2-T2V-A14B \
  --offload_model True --convert_model_dtype \
  --prompt "Test prompt" --save_path /Wan2.2/outputs
```

## Architecture

### Dual-Mode System

**MODE=build** (Local build with runtime downloads):
- Dockerfile builds base image (~8GB) from HuggingFace PyTorch GPU base
- `entrypoint.sh` downloads Wan2.2-T2V-A14B model (~126GB) from HuggingFace Hub at runtime
- Models cached in `/opt/Wan2.2/checkpoints` (mounted volume) for persistence
- Use for first-time EC2 deployments or development

**MODE=pull** (Registry-based):
- Pulls pre-built image from specified registry (GitHub CR, Docker Hub, ECR)
- Same runtime model download behavior via entrypoint
- Use for faster cold starts and reproducible deployments

### Inference Flow

1. **run.sh** parses prompt and configuration
2. **docker-compose** launches container with GPU access
3. **entrypoint.sh** ensures models are downloaded (one-time ~15-25 min)
4. **generate.py** executes inference pipeline:
   - Load T5 text encoder → encode prompt to embeddings
   - Initialize DiT transformer (14B MoE) with memory optimizations
   - Run diffusion denoising loop (50-100 steps)
   - VAE decode latents to video frames
   - Save MP4 to `/Wan2.2/outputs` (mounted from host `/opt/Wan2.2/outputs`)

### Memory Optimizations

The model requires ~48GB VRAM on a single GPU (L40S 48GB or H100 80GB). Critical flags in `run.sh`:

- `--offload_model True`: Moves inactive model components to CPU RAM
- `--convert_model_dtype`: Mixed precision (FP16/BF16) reduces VRAM from 80GB → 48GB
- Alternative: Add `--t5_cpu` to offload text encoder for tight memory budgets

### Infrastructure Components

- **Terraform**: Provisions EC2 instance (g6e.4xlarge, p5.4xlarge, or p4d.24xlarge)
- **Deep Learning AMI**: Ubuntu 22.04 with CUDA 12.6, cuDNN, NVIDIA drivers pre-installed
- **SSM Access**: AWS Systems Manager for shell access (no SSH keys or inbound ports)
- **Security Group**: Egress-only (SSM uses outbound HTTPS)
- **IAM Role**: `AmazonSSMManagedInstanceCore` policy for SSM access

## File Structure

```
.
├── Dockerfile              # Multi-stage build: HF base + Wan2.2 repo + dependencies
├── docker-compose.yml      # GPU configuration, volume mounts
├── entrypoint.sh          # Downloads models from HF Hub if not cached
├── run.sh                 # Main inference script (mode-aware)
├── build-and-push.sh      # Build + tag + push to registry
├── .env.example           # Template configuration
├── terraform/
│   ├── main.tf           # EC2, IAM, security group definitions
│   ├── variables.tf      # Configurable parameters (region, instance type)
│   ├── outputs.tf        # Instance ID, public IP
│   └── user_data.sh      # EC2 initialization (docker-compose install, GPU check)
├── ARCHITECTURE.md        # Detailed system diagrams and workflows
└── README.md             # User-facing documentation
```

## Important Implementation Details

### Model Download Mechanism

The `entrypoint.sh` script runs on every container start and checks if models exist in `/Wan2.2/checkpoints/Wan2.2-T2V-A14B`. On first run, it downloads via:

```bash
huggingface-cli download Wan-AI/Wan2.2-T2V-A14B \
  --local-dir /Wan2.2/checkpoints/Wan2.2-T2V-A14B \
  --resume-download
```

The `/Wan2.2` directory is mounted from `/opt/Wan2.2` on the host, ensuring persistence across container restarts.

### Docker Image vs Model Storage

**Docker Image** (~8GB):
- HuggingFace transformers-pytorch-gpu:latest base
- Wan2.2 repository code
- Python dependencies (requirements.txt + flash-attn)

**Models** (~126GB, downloaded at runtime):
- Stored outside Docker image to avoid:
  - Massive image sizes (36GB+)
  - Slow docker pull times
  - Inflexible updates (no rebuild for model changes)
  - High registry storage costs

### Terraform State

The project does NOT include remote state configuration. When working with Terraform:
- State is stored locally in `terraform/terraform.tfstate`
- For team environments, consider adding S3 backend in `main.tf`
- Never commit `terraform.tfstate` to version control

### GPU Instance Requirements

- **Minimum**: g6e.4xlarge (L40S 48GB VRAM)
- **Recommended for research**: Same, ~$241/month for 8h/day usage
- **High performance**: p5.4xlarge (H100 80GB) but significantly more expensive
- **AMI**: Must be Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)
- **CUDA**: 12.6+ required for flash-attn compilation

## Configuration Files

### .env File

Controls operational mode and image sources:

```bash
MODE=pull                                    # "build" or "pull"
DOCKER_IMAGE=ghcr.io/org/wan22-t2v:v2.2    # Registry image for MODE=pull
LOCAL_IMAGE_TAG=wan22-t2v:latest            # Local tag for MODE=build
```

### docker-compose.yml

Key volume mount:
- `/opt/Wan2.2:/Wan2.2` - Single directory for checkpoints and outputs (simplified structure)

Directory structure on host:
- `/opt/Wan2.2/checkpoints/` - Model weights (~126GB)
- `/opt/Wan2.2/outputs/` - Generated videos

GPU configuration uses `deploy.resources.reservations` with nvidia driver for GPU access.

## Development Workflow

When modifying inference parameters:
1. Edit `run.sh` to change default flags passed to `generate.py`
2. Common adjustments: resolution (`--size`), offload settings, inference steps
3. No image rebuild needed unless changing dependencies

When updating model versions:
1. Modify `entrypoint.sh` to point to new HuggingFace model ID
2. Clear `/opt/Wan2.2/checkpoints` on host to force re-download
3. For registry workflow: rebuild and push with new tag

When modifying Terraform infrastructure:
1. Edit `terraform/variables.tf` for new instance types or regions
2. Run `terraform plan` to preview changes before applying
3. Note: AMI IDs are region-specific; update `local.dlami_id` in `main.tf` if changing regions

## Troubleshooting

**Image build fails at flash-attn**:
- Ensure CUDA toolkit is properly installed: `nvcc --version`
- Deep Learning AMI should have this pre-configured
- flash-attn requires CUDA 11.8+ and compatible gcc

**GPU not detected in container**:
- Verify on host: `nvidia-smi`
- Check nvidia-docker2: `docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi`
- Ensure Deep Learning AMI has NVIDIA Container Toolkit

**Out of memory errors**:
- Verify `--offload_model True` and `--convert_model_dtype` are set in `run.sh`
- Add `--t5_cpu` flag to offload text encoder
- Reduce resolution: `1280*720` → `960*540`
- Consider using smaller TI2V-5B model (24GB VRAM)

**Model download fails**:
- Check HuggingFace Hub connectivity
- Verify sufficient disk space (~130GB needed)
- Use `--resume-download` flag (already in entrypoint.sh)

**SSM connection fails**:
- Verify IAM instance profile is attached: `aws ec2 describe-instances`
- Check SSM agent status: `sudo systemctl status amazon-ssm-agent`
- Ensure security group allows outbound HTTPS (port 443)

**Terraform apply hangs**:
- Check AWS credentials: `aws sts get-caller-identity`
- Verify region/AZ availability for GPU instances
- Some regions have quota limits on GPU instances

## Cost Optimization

- **Stop instances when idle**: EC2 compute charges stop, EBS persists
- **Use Spot instances**: Add `instance_market_options` in Terraform (not currently configured)
- **Registry choice**: GitHub Container Registry is free for public images
- **Intermittent usage**: 40 hours/month = ~$60 vs 24/7 = ~$1,089

## Research Reproducibility

For publishing research results, the Docker-native approach ensures:
- Exact environment (Docker image with pinned dependencies)
- Exact model weights (HuggingFace Hub with SHA256 verification)
- Cloud-agnostic deployment (AWS, GCP, Azure, or local GPU)
- Shareable via registry: `docker pull ghcr.io/org/wan22-t2v:v2.2`
