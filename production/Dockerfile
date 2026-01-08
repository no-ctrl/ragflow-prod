# Production Dockerfile
# Builds a self-contained RAGFlow image with custom configuration
# ready for Docker Registry publication.

FROM infiniflow/ragflow:v0.23.1

# 1. Copy custom configuration
COPY service_conf.yaml /ragflow/conf/service_conf.yaml

# 2. Copy MySQL initialization if needed (usually handled by separate DB container, but if embedding...)
# COPY init.sql /ragflow/init.sql

# 3. Set environment variables (optional defaults)
ENV DOC_ENGINE=elasticsearch
ENV PORT=9380

# 4. Entrypoint (inherit from base)
ENTRYPOINT ["./entrypoint.sh"]
