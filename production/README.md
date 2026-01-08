# RAGFlow Production Deployment - RunPod RTX 4090/5090

Production-ready RAGFlow with GPU-accelerated vLLM inference for NVIDIA RTX GPUs.

## Architecture

```
┌─────────────────────────────────────────┐
│     RAGFlow (Document Processing)       │
│  - Python 3.8 + FastAPI                  │
│  - Document parsers (PDF, DOCX, etc.)    │
│  - Custom Image: ragflow-custom-prod     │
│  - Baked-in config: service_conf.yaml    │
└──┬──────────┬──────────┬────────────┬───┘
   │          │          │            │
┌──▼────┐ ┌──▼──────┐ ┌─▼──────┐ ┌──▼────┐
│MySQL  │ │Elastic  │ │ MinIO  │ │ Redis │
│(Meta) │ │(Vector) │ │(Files) │ │(Cache)│
└───────┘ └─────────┘ └────────┘ └───────┘
                                     │
                              ┌──────▼──────┐
                              │    vLLM     │
                              │ RTX 4090/   │
                              │   5090 GPU  │
                              └─────────────┘
```

## Services

| Service | Purpose | Port | Storage |
|---------|---------|------|---------|
| **vLLM** | GPU LLM inference | 8000 | /workspace/vllm_models |
| **RAGFlow** | Main app + UI | 9380, 9381 | /workspace/ragflow_data |
| **Elasticsearch** | Vector storage | 9200 | /workspace/elasticsearch_data |
| **MySQL** | App database | 3306 | /workspace/mysql_data |
| **MinIO** | Object storage | 9000, 9001 | /workspace/minio_data |
| **Redis** | Cache/queue | 6379 | /workspace/redis_data |

## Quick Start (RunPod)

```bash
# 1. SSH to RunPod
ssh root@<runpod-ip>

# 2. Navigate to workspace
cd /workspace

# 3. Copy production files here
# (docker-compose.yml, .env, init.sql, service_conf.yaml, deploy.sh)

# 4. Edit .env - REPLACE PASSWORDS
nano .env

# 5. Set Hugging Face token (for downloading models)
# Get token: https://huggingface.co/settings/tokens
export HF_TOKEN=hf_...

# 6. Deploy
./deploy.sh

# 7. Monitor vLLM model download
docker logs -f ragflow_prod_vllm

# 8. Access UI
# http://<runpod-ip>:9380
```

## GPU Configuration Profiles (in `.env`)

The `.env` file contains pre-tuned profiles. Uncomment the block that matches your hardware:

### 🟢 Profile A: Standard (Default)
**Hardware**: RTX 3090 / 4090 / 5090
**Best for**: Stability, general use.
- Model: `Llama-3.1-8B-Instruct`
- Context: 8192 tokens
- VRAM: ~16GB (Safe margin)

### 🚀 Profile B: Performance (RTX 4090)
**Hardware**: RTX 4090 (24GB)
**Best for**: Max throughput on single 4090.
- Model: `Llama-3.1-8B-Instruct`
- Context: **16384 tokens** (Extended)
- VRAM: 95% utilization
- Throughput: High concurrency

### ⚡️ Profile C: Ultimate (RTX 5090)
**Hardware**: RTX 5090 (32GB+)
**Best for**: Massive context windows.
- Model: `Llama-3.1-8B-Instruct`
- Context: **32768 tokens** (Massive)
- VRAM: 95% utilization
- Batched Tokens: 32k

### 🧠 Profile D: Intelligence (RTX 5090)
**Hardware**: RTX 5090 (32GB+)
**Best for**: Reasoning (70B model).
- Model: `llama-3-70b-instruct-awq` (Quantized)
- Context: 4096 tokens
- Requirement: AWQ/GPTQ model version

## Model Selection

### Recommended Production Models

**8B Models** (RTX 4090/5090):
- `meta-llama/Llama-3.1-8B-Instruct` - Best general purpose
- `mistralai/Mistral-7B-Instruct-v0.3` - Fast inference
- `Qwen/Qwen2.5-7B-Instruct` - Multilingual

**70B Models** (RTX 5090 + quantization):
- `meta-llama/Llama-3.3-70B-Instruct` - Superior reasoning
- Requires AWQ/GPTQ quantization
- ~16GB VRAM with INT8

## Security Checklist

Before deployment:

- [ ] Replace `ELASTIC_PASSWORD` (32+ chars)
- [ ] Replace `MYSQL_PASSWORD` (32+ chars)
- [ ] Replace `MINIO_PASSWORD` (32+ chars)
- [ ] Replace `REDIS_PASSWORD` (32+ chars)
- [ ] Set `HF_TOKEN` for model downloads
- [ ] Verify firewall rules (ports 9380, 9381)
- [ ] Check `/workspace` is mounted

Generate passwords:
```bash
openssl rand -base64 32
```

## Verification

```bash
# Check all containers
docker compose ps

# Verify GPU access
docker exec ragflow_prod_vllm nvidia-smi

# Test vLLM API
curl http://localhost:8000/v1/models

# Check Elasticsearch
curl -u elastic:$ELASTIC_PASSWORD http://localhost:9200/_cluster/health

# Test vLLM inference
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "prompt": "Explain RAG in one sentence:",
    "max_tokens": 50
  }'
```

## Storage Estimates

| Component | Size | Notes |
|-----------|------|-------|
| vLLM models | ~5-140GB | Model-dependent |
| Elasticsearch | ~10GB/1M docs | Indexes + vectors |
| MySQL | ~1-5GB | Metadata |
| MinIO | Variable | Raw documents |
| Redis | ~100MB-1GB | Cache |
| Logs | ~1GB/month | With rotation |

**Total**: 20-200GB depending on model and usage

## Troubleshooting

### GPU Not Detected
```bash
# Check NVIDIA runtime
docker info | grep nvidia

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### vLLM OOM (Out of Memory)
```bash
# Reduce GPU memory usage
VLLM_GPU_MEMORY_UTIL=0.85  # Was 0.90

# Reduce context window
VLLM_MAX_MODEL_LEN=4096  # Was 8192

# Use smaller model
VLLM_MODEL=meta-llama/Llama-3.1-8B-Instruct  # Instead of 70B
```

### Slow Model Download
```bash
# Check download progress
docker logs -f ragflow_prod_vllm

# Use HF mirror if blocked
HF_ENDPOINT=https://hf-mirror.com
```

## Maintenance

```bash
# Stop all services
docker compose down

# Backup persistent data
tar -czf ragflow_backup_$(date +%Y%m%d).tar.gz \
  /workspace/mysql_data \
  /workspace/elasticsearch_data \
  /workspace/minio_data

# Update images
docker compose pull
docker compose up -d

# View logs
docker compose logs -f

# Monitor resources
docker stats
watch -n 1 nvidia-smi
```

## Performance Tuning

### High Throughput
```bash
# Increase concurrent requests
VLLM_MAX_NUM_SEQS=512

# Larger batch size
VLLM_MAX_BATCHED_TOKENS=16384
```

### Low Latency
```bash
# Reduce concurrency
VLLM_MAX_NUM_SEQS=64

# Smaller batches
VLLM_MAX_BATCHED_TOKENS=4096
```

## Files

- `docker-compose.yml` - Service definitions
- `.env` - Configuration (EDIT THIS)
- `deploy.sh` - Automated deployment
- `init.sql` - MySQL initialization
- `service_conf.yaml` - RAGFlow settings

## Support

- RAGFlow: https://ragflow.io/docs
- vLLM: https://docs.vllm.ai
- NVIDIA: https://docs.nvidia.com/datacenter/cloud-native/
