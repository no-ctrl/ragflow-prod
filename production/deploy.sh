# Quick Deployment Script for RunPod

#!/bin/bash
set -e

echo "🚀 RAGFlow Production Deployment - RunPod RTX 4090/5090"
echo "========================================================"

# Check GPU
echo "✓ Checking GPU..."
if ! nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA GPU not detected. Ensure nvidia-smi works."
    exit 1
fi
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# Check Docker
echo "✓ Checking Docker..."
if ! docker info &> /dev/null; then
    echo "❌ Docker not running"
    exit 1
fi

# Check NVIDIA Container Toolkit
echo "✓ Checking NVIDIA Container Toolkit..."
if ! docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA Container Toolkit not installed"
    echo "Install: apt-get update && apt-get install -y nvidia-container-toolkit"
    exit 1
fi

# Check /workspace
echo "✓ Checking /workspace mount..."
if [ ! -d "/workspace" ]; then
    echo "❌ /workspace directory not found"
    exit 1
fi
df -h /workspace

# Check .env passwords
echo "✓ Checking .env configuration..."
if grep -q "REPLACE_WITH_" .env; then
    echo "⚠️  WARNING: Found placeholder passwords in .env"
    echo "   MUST replace before deployment:"
    grep "REPLACE_WITH_" .env | sed 's/=.*//'
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Start deployment
echo "✓ Starting deployment..."
docker compose up -d

# Wait for services
echo "✓ Waiting for services to become healthy..."
sleep 10

# Check status
echo "✓ Checking service status..."
docker compose ps

# Verify GPU access
echo "✓ Verifying GPU access in RAGFlow container..."
if docker exec ragflow_prod_app command -v nvidia-smi &> /dev/null; then
    docker exec ragflow_prod_app nvidia-smi --query-gpu=name --format=csv,noheader
    echo "✅ GPU access confirmed"
else
    echo "⚠️  nvidia-smi not available in RAGFlow container"
fi

# Display access URLs
echo ""
echo "========================================================  "
echo "✅ Deployment Complete!"
echo "========================================================"
echo "RAGFlow UI:    http://$(hostname -I | awk '{print $1}'):9380"
echo "Admin Panel:   http://$(hostname -I | awk '{print $1}'):9381"
echo "MinIO Console: http://$(hostname -I | awk '{print $1}'):9001"
echo "========================================================"
echo "View logs: docker compose logs -f ragflow"
echo "Stop: docker compose down"
echo "========================================================"
