# Wan2.2 T2V Docker + Terraform Deployment

Docker-native MVP workflow for deploying Wan2.2-T2V-A14B on AWS EC2 with GPU support.

**Key Features:**
- 🐳 **Docker-native**: Models baked into image (100% reproducible)
- ☁️ **Cloud-agnostic**: Runs on AWS, GCP, Azure, or local machines
- 🔄 **Dual-mode**: Build locally OR pull pre-built image
- 🔒 **Zero SSH**: AWS Systems Manager (SSM) access only
- 💰 **Cost-optimized**: No EBS volumes, Docker image caching

## Prerequisites

- AWS account with GPU instance access (g6e.4xlarge or p5.4xlarge)
- AWS CLI configured with credentials
- Terraform >= 1.0
- Session Manager plugin installed (for SSM access)
- Docker registry account (optional, for push mode):
  - GitHub Container Registry (free for public images)
  - Docker Hub
  - Amazon ECR

## Architecture

- **Base Image**: `huggingface/transformers-pytorch-gpu:latest` (PyTorch 2.8.0, CUDA 12.6)
- **Model Storage**: Baked into Docker image (~38GB total)
- **Target GPU**: Single GPU (L40S 48GB or H100 80GB)
- **AMI**: Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)
- **Access**: AWS Systems Manager (SSM) - no SSH keys or open ports required

## Quick Start

### Workflow 1: Build Mode (First Time on EC2)

Use this when you want to build the image on EC2 for the first time.

```bash
# 1. Deploy EC2 Instance
cd terraform
terraform init

cat > terraform.tfvars <<EOF
aws_region        = "us-east-1"
availability_zone = "us-east-1a"
instance_type     = "g6e.4xlarge"
EOF

terraform apply

# 2. Connect via SSM
aws ssm start-session --target $(terraform output -raw instance_id)

# 3. Clone repository
Sudo git clone https://github.com/brandonmandzik/wan22-docker.git
cd wan22-docker

# 4. Configure for build mode
sudo cp .env.example .env
# Edit .env: Set MODE=build

# 5. Run inference (builds image automatically on first run)
sudo ./run.sh "Warmup" 
# First run: ~25-30 minutes (builds image + inference)
# Subsequent runs: ~5-10 minutes (inference only)
```

### Workflow 2: Build + Push Mode (Create Reusable Image)

Use this to build once, push to registry, and reuse everywhere.

```bash
# After building locally (Workflow 1)

# 1. Login to your registry
# GitHub Container Registry:
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Docker Hub:
docker login

# Amazon ECR:
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# 2. Build and push
./build-and-push.sh ghcr.io/your-org/wan22-t2v:v2.2
# Takes 20-30 min to build + 10-20 min to push (one time only)

# 3. Update .env for pull mode
cat > .env <<EOF
MODE=pull
DOCKER_IMAGE=ghcr.io/your-org/wan22-t2v:v2.2
LOCAL_IMAGE_TAG=wan22-t2v:latest
EOF

# 4. Now anyone can pull and run!
```

### Workflow 3: Pull Mode (Use Pre-built Image)

Use this after someone has pushed the image to a registry.

```bash
# 1. Deploy EC2 (same as above)
terraform apply

# 2. Connect via SSM
aws ssm start-session --target $(terraform output -raw instance_id)

# 3. Clone repository
git clone <your-repo-url>
cd wan22-docker

# 4. Configure for pull mode
cat > .env <<EOF
MODE=pull
DOCKER_IMAGE=ghcr.io/your-org/wan22-t2v:v2.2
LOCAL_IMAGE_TAG=wan22-t2v:latest
EOF

# 5. Run inference (pulls image automatically)
./run.sh "A serene lake at sunset"
# First run: ~8-12 minutes (pulls 38GB + inference)
# Subsequent runs: ~5-10 minutes (inference only)
```

## Usage
  Warm container (models stay loaded):
  # Start once
  docker-compose up -d

  # Run inference (repeat as needed, fast)
  docker-compose exec wan22 python generate.py [your flags...]

  # Stop when done
  docker-compose down

  Cold container (existing behavior):
  ./run.sh "prompt
### Basic Inference

```bash
./run.sh "your prompt here"
```

### Custom Resolution

```bash
./run.sh "your prompt" "1920*1080"
```

### Check Mode

```bash
cat .env
# Shows current MODE setting (build or pull)
```

## File Structure

```
.
├── Dockerfile                 # Multi-stage build with baked models
├── docker-compose.yml         # GPU config (mode-agnostic)
├── .env                       # Configuration (MODE=build or MODE=pull)
├── .env.example               # Template configuration
├── build-and-push.sh          # Build image and push to registry
├── run.sh                     # Smart inference script (auto-detects mode)
├── terraform/
│   ├── main.tf               # EC2, IAM, security group (no EBS!)
│   ├── variables.tf          # Configurable parameters
│   ├── outputs.tf            # Connection info
│   └── user_data.sh          # Minimal EC2 setup script
└── README.md
```

## Configuration (.env file)

```bash
# MODE: "build" (build locally) or "pull" (pull from registry)
MODE=build

# Registry image (when MODE=pull)
DOCKER_IMAGE=ghcr.io/your-org/wan22-t2v:v2.2

# Local image tag (when MODE=build)
LOCAL_IMAGE_TAG=wan22-t2v:latest
```

## Cold Start Times

```
Build Mode (first run on new EC2):
1. terraform apply                      → 2-3 min
2. SSM connect + git clone              → 30 sec
3. ./run.sh (auto-build + inference)    → 25-30 min
Total: ~30 min

Build Mode (subsequent runs):
1. ./run.sh (cached image)              → 5-10 min
Total: ~5-10 min ✓

Pull Mode (first run):
1. terraform apply                      → 2-3 min
2. SSM connect + git clone              → 30 sec
3. ./run.sh (pull + inference)          → 8-12 min
Total: ~12 min ✓✓

Pull Mode (subsequent runs):
1. ./run.sh (cached image)              → 5-10 min
Total: ~5-10 min ✓✓✓
```

## Cost Breakdown

```
Monthly Compute (g6e.4xlarge):
- Full-time (24/7): ~$1,089/month
- Part-time (8h/day, 20 days): ~$241/month
- Intermittent (40h/month): ~$60/month

Storage Costs:
- Docker image in registry:
  - GitHub CR (public): FREE
  - GitHub CR (private): FREE (with limits)
  - Amazon ECR: $3.80/month (38GB × $0.10/GB)
  - Docker Hub Pro: $5/month (unlimited)

vs Old EBS Approach:
- 200GB EBS: $16/month
- Savings: Up to $12/month (75% cheaper with GitHub CR)
```

## Registry Options

### GitHub Container Registry (Recommended for Research)
```bash
# Free for public images, perfect for reproducible research
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
./build-and-push.sh ghcr.io/your-org/wan22-t2v:v2.2
```

### Docker Hub
```bash
docker login
./build-and-push.sh your-username/wan22-t2v:v2.2
```

### Amazon ECR
```bash
# Create repository
aws ecr create-repository --repository-name wan22-t2v --region us-east-1

# Login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# Build and push
./build-and-push.sh 123456789.dkr.ecr.us-east-1.amazonaws.com/wan22-t2v:v2.2
```

## Reproducibility for Research

This setup is ideal for publishing research:

```markdown
## Reproducibility Statement

Our experiments used Docker image: `ghcr.io/your-org/wan22-t2v:v2.2`

To reproduce results:
```bash
# On any machine with Docker + GPU
docker pull ghcr.io/your-org/wan22-t2v:v2.2
docker run --gpus all -v ./outputs:/outputs \
  ghcr.io/your-org/wan22-t2v:v2.2 \
  python generate.py --task t2v-A14B --size 1280*720 \
  --ckpt_dir /models/Wan2.2-T2V-A14B \
  --offload_model True --convert_model_dtype \
  --prompt "Test prompt" --save_path /outputs
```

✓ Exact environment (Docker image)
✓ Exact dependencies (baked in)
✓ Exact model weights (SHA256 verified)
✓ Runs on AWS, GCP, Azure, or local GPU
```

## Troubleshooting

### GPU Not Detected
```bash
# On EC2 instance
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi
```

### Image Build Fails (flash-attn)
```bash
# Most common failure point
# Ensure Deep Learning AMI has proper CUDA toolkit
nvcc --version
```

### Pull Fails (Authentication)
```bash
# GitHub CR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Check token has read:packages permission
```

### Out of Memory
```bash
# Verify optimizations are enabled in run.sh:
--offload_model True --convert_model_dtype

# Or use smaller model variant (TI2V-5B requires only 24GB)
```

## Advanced Usage

### Run Without Wrapper Scripts
```bash
# Direct Docker run (no docker-compose)
docker run --gpus all \
  -v ./outputs:/outputs \
  ghcr.io/your-org/wan22-t2v:v2.2 \
  python generate.py --task t2v-A14B --size 1280*720 \
  --ckpt_dir /models/Wan2.2-T2V-A14B \
  --offload_model True --convert_model_dtype \
  --prompt "A serene lake" --save_path /outputs
```

### Update Model to New Version
```bash
# Update Dockerfile to download new model version
# Rebuild and push with new tag
./build-and-push.sh ghcr.io/your-org/wan22-t2v:v2.3

# Update .env
DOCKER_IMAGE=ghcr.io/your-org/wan22-t2v:v2.3
```

## References

- [Wan2.2 GitHub](https://github.com/Wan-Video/Wan2.2)
- [HuggingFace Model Card](https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B)
- [AWS Deep Learning AMI](https://aws.amazon.com/releasenotes/aws-deep-learning-base-oss-nvidia-driver-gpu-ami-ubuntu-22-04/)
- [Docker GPU Support](https://docs.docker.com/compose/how-tos/gpu-support/)

## License

Follow Wan2.2 model license terms. For research use only.
