# Production Dockerfile for ComfyUI with complex dependencies
# Based on best practices from mmartial/ComfyUI-Nvidia-Docker and ai-dock/comfyui

ARG CUDA_VERSION=12.1.0
ARG CUDNN_VERSION=8
ARG UBUNTU_VERSION=22.04
ARG PYTHON_VERSION=3.11

# Stage 1: CUDA base with all system dependencies
FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-runtime-ubuntu${UBUNTU_VERSION} AS base

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CUDA_MODULE_LOADING=LAZY

# Install system dependencies (comprehensive list for custom nodes)
RUN apt-get update && apt-get install -y \
    # Python
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    # Git (required for many custom nodes)
    git \
    git-lfs \
    # OpenCV and graphics dependencies
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    libgl1-mesa-glx \
    libglu1-mesa \
    # Audio/Video processing
    ffmpeg \
    libsndfile1 \
    # Additional tools
    wget \
    curl \
    vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python

# Stage 2: Python environment setup
FROM base AS python-env

WORKDIR /app

# Create and activate virtual environment (using comfy_venv name for consistency)
RUN python -m venv /app/comfy_venv

# Use the virtual environment
ENV VIRTUAL_ENV=/app/comfy_venv
ENV PATH="/app/comfy_venv/bin:$PATH"

# Upgrade pip to latest
RUN pip install --upgrade pip wheel setuptools

# Copy requirements files
COPY requirements-frozen.txt .
COPY custom-nodes-requirements.txt .

# Install PyTorch with CUDA support (CRITICAL: must be before other packages)
RUN pip install torch==2.1.2+cu121 torchvision==0.16.2+cu121 torchaudio==2.1.2+cu121 \
    --index-url https://download.pytorch.org/whl/cu121 \
    --no-cache-dir

# Install xformers for memory optimization (recommended for production)
RUN pip install xformers==0.0.23 --no-cache-dir

# Install frozen requirements (exact versions from your environment)
RUN pip install --no-cache-dir -r requirements-frozen.txt || \
    echo "Some packages failed, continuing..."

# Install custom node requirements (may have conflicts, install gracefully)
RUN if [ -f custom-nodes-requirements.txt ]; then \
        grep -v '^#' custom-nodes-requirements.txt | grep -v '^$' | while IFS= read -r req; do \
            echo "Installing: $req"; \
            pip install --no-cache-dir "$req" 2>/dev/null || echo "⚠️  Failed: $req (may be optional)"; \
        done; \
    fi

# Install commonly missing packages for custom nodes
RUN pip install --no-cache-dir \
    opencv-python \
    opencv-contrib-python \
    insightface \
    onnxruntime-gpu \
    mediapipe \
    pandas \
    numexpr \
    GitPython \
    google-search-results \
    || echo "Some optional packages failed"

# Stage 3: Final application image
FROM python-env AS final

WORKDIR /app

# Clone ComfyUI (specific commit for reproducibility)
ARG COMFYUI_COMMIT=master
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    if [ "$COMFYUI_COMMIT" != "master" ]; then \
        git checkout $COMFYUI_COMMIT; \
    fi

# Clone essential custom nodes instead of copying local files
RUN cd /app/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/crystian/ComfyUI-Crystools.git && \
    git clone https://github.com/jags111/efficiency-nodes-comfyui.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git

# Install custom node dependencies
RUN cd /app/custom_nodes/ComfyUI-Manager && \
    if [ -f "requirements.txt" ]; then pip install -r requirements.txt; fi || true

# Copy configuration files if they exist
COPY extra_model_paths.yaml* /app/

# Create necessary directories with proper permissions
RUN mkdir -p \
    /app/models/checkpoints \
    /app/models/clip \
    /app/models/clip_vision \
    /app/models/controlnet \
    /app/models/embeddings \
    /app/models/loras \
    /app/models/upscale_models \
    /app/models/vae \
    /app/models/hypernetworks \
    /app/models/ipadapter \
    /app/models/instantid \
    /app/models/animatediff_models \
    /app/models/animatediff_motion_lora \
    /app/models/inpaint/brushnet \
    /app/models/inpaint/powerpaint \
    /app/input \
    /app/output \
    /app/temp \
    /app/user

# Copy and setup entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose ComfyUI port
EXPOSE 8188

# Set up health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8188/system_stats')" || exit 1

# Use entrypoint for initialization, CMD for the actual command
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["python", "-u", "main.py", "--listen", "0.0.0.0", "--port", "8188"] 