#!/bin/bash

# Exit on any error
set -e

# Check if required environment variables are set
if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
    echo "Error: Required environment variables not set"
    echo "Please set: DOCKER_USERNAME, DOCKER_PASSWORD"
    exit 1
fi

# Create .docker directory if it doesn't exist
mkdir -p .docker

# Create Docker config.json with registry auth
echo "Creating Docker registry configuration..."
DOCKER_AUTH=$(echo -n "$DOCKER_USERNAME:$DOCKER_PASSWORD" | base64)
cat > .docker/config.json << EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "${DOCKER_AUTH}"
    }
  }
}
EOF

# Create the secret in Kubernetes
echo "Creating Kubernetes secret..."
kubectl create namespace crawl4ai --dry-run=client -o yaml | kubectl apply -f -

# Apply kustomization to create the secret
kubectl apply -k k8s/base

echo "Docker registry secret created successfully!" 