#!/bin/bash
set -e

# ============================================================================
# RunPod Start Script for RAGFlow (RTX 4090 / 5090)
# ============================================================================
# Paste this into the "Container Start Command" field in RunPod Template.
# This script ensures the environment is set up and services are running.
# ============================================================================

# 1. Basic Setup
cd /workspace

# 2. Check if git repo exists
if [ ! -d "ragflow" ]; then
    echo "🚀 Initializing RAGFlow Production Environment..."
    echo "🚀 Initializing RAGFlow Production Environment..."
    # Auto-clone configuration from GitHub
    git clone https://github.com/no-ctrl/ragflow-prod.git ragflow
    
    if [ ! -d "ragflow" ]; then
        echo "❌ Failed to clone repository. Check internet connection or URL."
        sleep 3600
        exit 1
    fi
else
    echo "✅ RAGFlow directory found."
    # Optional: Auto-update if it's a git repo
    if [ -d "ragflow/.git" ]; then
        echo "🔄 Updating repository..."
        cd ragflow
        git pull || echo "⚠️ Git pull failed, continuing with current version."
        cd ..
    fi
fi

# Move to production dir
if [ -d "ragflow/production" ]; then
    cd ragflow/production
elif [ -d "production" ]; then
    cd production
else
    echo "❌ production directory not found. Please upload the kit."
    sleep 3600 # Keep container alive for debugging
    exit 1
fi

# 3. Environment Configuration (Auto-Optimization)
if [ ! -f ".env" ]; then
    echo "⚙️  Generating optimized .env..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        # Fallback if example missing
        touch .env
    fi
    
    # Detect GPU VRAM
    if command -v nvidia-smi &> /dev/null; then
        VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
        echo "🔍 Detected GPU VRAM: ${VRAM} MB"
        
        if [ "$VRAM" -gt 30000 ]; then
            echo "⚡️ RTX 5090 detected (32GB+). Applying Profile C (Ultimate)."
            sed -i 's/VLLM_MAX_MODEL_LEN=8192/VLLM_MAX_MODEL_LEN=16384/' .env
            sed -i 's/VLLM_MAX_NUM_SEQS=256/VLLM_MAX_NUM_SEQS=512/' .env
        elif [ "$VRAM" -gt 22000 ]; then
            echo "🚀 RTX 4090 detected (24GB). Applying Profile B (Performance)."
            sed -i 's/VLLM_MAX_MODEL_LEN=8192/VLLM_MAX_MODEL_LEN=16384/' .env
        else
            echo "🟢 Standard GPU detected. Using Profile A."
        fi
    else
        echo "⚠️  nvidia-smi not found. Skipping GPU optimization."
    fi
    
    # Generate passwords if standard placeholder exists
    sed -i "s/REPLACE_WITH_STRONG_ES_PASSWORD/$(openssl rand -hex 16)/" .env || true
    sed -i "s/REPLACE_WITH_STRONG_MYSQL_PASSWORD/$(openssl rand -hex 16)/" .env || true
    sed -i "s/REPLACE_WITH_STRONG_MINIO_PASSWORD/$(openssl rand -hex 16)/" .env || true
    sed -i "s/REPLACE_WITH_STRONG_REDIS_PASSWORD/$(openssl rand -hex 16)/" .env || true
fi

# 4. Start Services via deploy.sh
if [ -f "deploy.sh" ]; then
    chmod +x deploy.sh
    ./deploy.sh
else
    echo "⚠️  deploy.sh not found. Using docker compose directly."
    docker compose up -d
fi

# 5. Health Check Loop
echo "⏳ Waiting for RAGFlow UI..."
for i in {1..30}; do
    if curl -s http://localhost:9380 > /dev/null; then
        echo "✅ RAGFlow UI is UP!"
        break
    fi
    sleep 5
done

echo ""
echo "🎉 RAGFlow Deployed Successfully!"
echo "👉 Access Methods:"
echo "   1. RunPod Public IP + Port 9380 (Check 'Connect' button)"
echo "   2. SSH Tunnel: ssh -L 9380:localhost:9380 root@<ip> -p <ssh-port>"
echo ""
echo "To follow logs: tail -f /workspace/ragflow_logs/ragflow_server.log"

# Keep container running
tail -f /dev/null
