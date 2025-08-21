#!/bin/bash
# docker-entrypoint.sh - Production entrypoint with dependency verification

set -e

# Activate virtual environment
source /app/comfy_venv/bin/activate

echo "============================================"
echo "🚀 ComfyUI Docker Container Starting"
echo "============================================"
echo "📅 Date: $(date)"
echo "🐍 Python: $(python --version)"

# Verify CUDA availability
echo ""
echo "🎮 GPU Status:"
python << EOF
import torch
print(f"  PyTorch Version: {torch.__version__}")
print(f"  CUDA Available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"  CUDA Version: {torch.version.cuda}")
    print(f"  GPU Count: {torch.cuda.device_count()}")
    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        print(f"  GPU {i}: {props.name}")
        print(f"    Memory: {props.total_memory / 1024**3:.1f} GB")
        print(f"    Compute Capability: {props.major}.{props.minor}")
EOF

# Quick dependency check for custom nodes
echo ""
echo "🔧 Verifying custom nodes..."
failed_imports=""
for dir in /app/custom_nodes/*/; do
    if [ -d "$dir" ] && [ "$(basename $dir)" != "__pycache__" ]; then
        node_name=$(basename "$dir")
        
        # Run install.py if exists
        if [ -f "$dir/install.py" ]; then
            echo "  Running install.py for $node_name..."
            (cd "$dir" && python install.py 2>/dev/null) || echo "    ⚠️  Install script failed (may be normal)"
        fi
        
        # Try importing the node
        if ! python -c "import sys; sys.path.insert(0, '/app'); __import__('custom_nodes.${node_name}')" 2>/dev/null; then
            failed_imports="$failed_imports $node_name"
        fi
    fi
done

if [ -n "$failed_imports" ]; then
    echo "  ⚠️  Some nodes failed to import:$failed_imports"
    echo "  (They may work anyway or load dependencies at runtime)"
fi

# Set memory optimization environment variables
export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:512"
export CUDA_LAUNCH_BLOCKING=0
export CUDNN_BENCHMARK=1

echo ""
echo "✅ Initialization complete"
echo "🌐 Starting ComfyUI server..."
echo "============================================"

# Execute the main command
exec "$@" 