# 🚀 RunPod Deployment Guide (RTX 4090 / 5090)

This guide details how to create a **RunPod Template** for your optimized RAGFlow production stack.

## 1. Create a New Template

Go to [RunPod Templates](https://www.runpod.io/console/templates) and click **"New Template"**.

### General Configuration
- **Template Name**: `RAGFlow Production (vLLM + RTX Optimized)`
- **Container Image**: `runpod/base:0.6.2-cuda12.4.1` (Includes Docker, NVIDIA drivers, CUDA)
- **Container Disk**: `50 GB` (Minimum for Docker images)
- **Volume Disk**: `200 GB` (Recommended for Models + ES Data)
- **Volume Mount Path**: `/workspace` (Critical: Config relies on this)

### Environment Variables
Add these to the template to allow runtime configuration:

| Key | Default Value | Description |
|-----|---------------|-------------|
| `HF_TOKEN` | (Empty) | Hugging Face Token for accessing gated models (Llama 3) |
| `RAGFLOW_IMAGE` | `docker.io/01filip01f/ragflow-custom-prod:v1.0.0` | Custom Production Image |
| `OPTIMIZATION_PROFILE` | `AUTO` | `AUTO`, `A` (Std), `B` (4090), `C` (5090) |

### Docker Configuration
- **Expose HTTP Ports**:
    - `9380` (RAGFlow UI)
    - `9381` (Admin API)
    - `8000` (vLLM API)
    - `9001` (MinIO Console)
- **Expose TCP Ports**: `9380,8000`

### Start Command (The Magic ✨)
Copy the contents of `production/runpod_start.sh` into the **"Docker Command"** or **"Start Script"** field.
*Ensure you either host your config in a git repo or upload it manually.*

---

## 2. Deploying a Pod

1. **Select GPU**:
   - **RTX 4090 (24GB)**: Good for Llama-3-8B with large context (16k).
   - **RTX 5090 (32GB+)**: Best for Llama-3-70B (Quantized) or huge context (32k).
   - **RTX 6000 Ada (48GB)**: Ultimate performance.

2. **Select Your Template**: Choose the `RAGFlow Production` template you created.

3. **Start Pod**.

---

## 3. Post-Deployment Steps

Once the Pod is Running:

1. **Upload Configuration** (If not git-cloned):
   - Use the "Connect" -> "Jupyter Lab" or "Web Terminal".
   - Drag & Drop the `production/` folder to `/workspace/`.

2. **Verify Auto-Optimization**:
   - The start script should have detected your GPU.
   - Check `.env`: `cat /workspace/production/.env`
   - Look for `VLLM_MAX_MODEL_LEN` (Should be 16384 for 4090/5090).

3. **Access UI**:
   - RunPod offers "TCP Port Mappings". Find the public IP and port mapping for `9380`.
   - URL: `http://<public-ip>:<mapped-port>`

---

## ⚡️ Optimization Details (How it works)

The `runpod_start.sh` script performs **Hardware-Aware Tuning**:

### 🟢 RTX 4090 Profile
- **VRAM**: 24GB
- **Context**: 16k tokens (Extended)
- **Throughput**: 95% GPU utilization
- **Batching**: Aggressive

### ⚡️ RTX 5090 Profile
- **VRAM**: 32GB (estimated)
- **Context**: 32k tokens (Massive)
- **Concurrency**: 2x relative to 4090
- **Model Support**: Ready for 70B INT8 quantization

### 💾 Storage Optimization
- All writes go to `/workspace` (Network Volume).
- **Log Rotation**: JSON logging limited to 30MB total per container to distinguish from system failures vs disk full.
- **Shared Memory**: `ipc: host` enabled for vLLM to prevent PyTorch crashes.

---

## 🛠 Troubleshooting

**"Disk Full" Error**:
Increase the **Volume Disk** size in RunPod settings, not Container Disk. Models require huge space.

**"OOM" / Crash on Load**:
Edit `.env` and reduce `VLLM_GPU_MEMORY_UTIL` to `0.85`.
Restart: `docker compose restart vllm`
