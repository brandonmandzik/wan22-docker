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
RUN pip install --no-cache-dir flash-attn --no-build-isolation

# Install HuggingFace CLI for model downloads
RUN pip install --no-cache-dir -U "huggingface_hub[cli]"

# Set environment variables for HuggingFace cache
ENV HF_HOME=/models
ENV TRANSFORMERS_CACHE=/models

# Create output and model directories
RUN mkdir -p /outputs /models

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /workspace/wan2.2

# Use entrypoint for model downloads
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
