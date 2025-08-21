# ComfyUI Production Docker

🚀 **Production-ready ComfyUI Docker setup with 50+ custom nodes**

## Features
- ✅ **Python 3.11.10** (exact environment match)
- ✅ **50 Custom Nodes** + 324 packages captured
- ✅ **CUDA 12.1** + PyTorch optimized
- ✅ **GitHub Actions CI/CD** for automated builds
- ✅ **RunPod ready** template

## Quick Start

### 1. RunPod Template
- **Container Image**: `ghcr.io/wearekhepri/comfyui-production-docker:latest`
- **Container Disk**: 20GB
- **Expose HTTP Port**: 8188
- **Docker Command**: `python -u main.py --listen 0.0.0.0 --port 8188`

### 2. Local Docker
```bash
docker run -d -p 8188:8188 \
  --gpus all \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/output:/app/output \
  ghcr.io/wearekhepri/comfyui-production-docker:latest
```

## What's Included
- **Custom Nodes**: efficiency-nodes, was-ns, pulid, layerstyle, tinyterranodes + 45 more
- **Optimizations**: xformers, memory management, CUDA optimizations
- **Production Ready**: Health checks, proper logging, security scanning

## Build Info
- **Base**: NVIDIA CUDA 12.1 + Ubuntu 22.04
- **Python**: 3.11.10 (matches captured environment)
- **Custom Nodes**: All dependencies pre-installed
- **Size**: ~8GB optimized image

Built from exact environment capture with all dependencies frozen.
