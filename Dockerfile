# ============================================
# Lightweight Dockerfile for Wan2.2 T2V
# Models downloaded at runtime from HuggingFace Hub
# ============================================

FROM huggingface/transformers-pytorch-gpu:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone Wan2.2 repository
WORKDIR /workspace
RUN git clone https://github.com/Wan-Video/Wan2.2.git /workspace/wan2.2

# Install Python dependencies
WORKDIR /workspace/wan2.2
RUN pip install --no-cache-dir -r requirements.txt

# Install flash-attn with maximum parallelization (matches user_data_ami_setup_14b.sh)
# Ninja enables parallel builds (13-16 cores), TORCH_CUDA_ARCH_LIST optimizes for L40S/H100 only
RUN pip install --no-cache-dir psutil packaging ninja && \
    TORCH_CUDA_ARCH_LIST="8.9;9.0" pip install --no-cache-dir flash-attn --no-build-isolation

# Install HuggingFace CLI for model downloads
RUN pip install --no-cache-dir -U "huggingface_hub[cli]"

# Set environment variables for HuggingFace cache
ENV HF_HOME=/Wan2.2
ENV TRANSFORMERS_CACHE=/Wan2.2

# Create Wan2.2 directory for checkpoints and outputs
RUN mkdir -p /Wan2.2/checkpoints /Wan2.2/outputs

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /workspace/wan2.2

# Use entrypoint for model downloads
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
