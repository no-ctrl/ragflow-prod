#!/bin/bash
set -e

# Configuration
IMAGE_NAME="ragflow-custom-prod"
TAG="v1.0.0"
REGISTRY=""  # e.g., "docker.io/myuser" or "ghcr.io/myorg"

echo "🐳 Building RAGFlow Production Image..."
echo "========================================"

if [ -z "$REGISTRY" ]; then
    echo "⚠️  No registry configured in script."
    read -p "🔹 Enter your Docker Registry (e.g., 'docker.io/username'): " USER_REGISTRY
    
    if [ -z "$USER_REGISTRY" ]; then
        echo "❌ No registry provided. Building locally only as '$IMAGE_NAME:$TAG'"
        FULL_IMAGE_NAME="$IMAGE_NAME:$TAG"
    else
        REGISTRY="$USER_REGISTRY"
        FULL_IMAGE_NAME="$REGISTRY/$IMAGE_NAME:$TAG"
    fi
else
    FULL_IMAGE_NAME="$REGISTRY/$IMAGE_NAME:$TAG"
fi

echo "Building: $FULL_IMAGE_NAME"
docker build --platform linux/amd64 -t "$FULL_IMAGE_NAME" .

# Also tag as latest
LATEST_IMAGE_NAME="$REGISTRY/$IMAGE_NAME:latest"
docker tag "$FULL_IMAGE_NAME" "$LATEST_IMAGE_NAME"

echo ""
echo "✅ Build Complete!"
echo "Run locally:"
echo "  docker run -p 9380:9380 $FULL_IMAGE_NAME"
echo ""

if [ ! -z "$REGISTRY" ]; then
    echo "Pushing to registry..."
    docker push "$FULL_IMAGE_NAME"
    docker push "$LATEST_IMAGE_NAME"
    echo "✅ Pushed to $FULL_IMAGE_NAME and $LATEST_IMAGE_NAME"
else
    echo "To push, edit this script and set REGISTRY variable."
fi
