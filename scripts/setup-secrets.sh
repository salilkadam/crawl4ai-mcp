#!/bin/bash

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI is not installed. Please install it first:"
    echo "https://cli.github.com/manual/installation"
    exit 1
fi

# Check if user is logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "Please login to GitHub first using: gh auth login"
    exit 1
fi

# Source the .env file
if [ ! -f .env ]; then
    echo ".env file not found"
    exit 1
fi

source .env

# Set the repository name
REPO="salilkadam/crawl4ai-mcp"

# Check if repository exists
if ! gh repo view "$REPO" &> /dev/null; then
    echo "Repository $REPO does not exist. Creating it..."
    gh repo create "$REPO" --public --source=. --remote=origin --push
fi

# Function to set GitHub secret
set_secret() {
    local secret_name=$1
    local secret_value=$2
    
    echo "Setting secret: $secret_name for repository: $REPO"
    gh secret set "$secret_name" -b "$secret_value" -R "$REPO"
}

# Set Docker credentials
set_secret "DOCKER_USERNAME" "$DOCKER_USERNAME"
set_secret "DOCKER_PASSWORD" "$DOCKER_PASSWORD"

# Set ArgoCD credentials
set_secret "ARGOCD_SERVER" "$ARGOCD_SERVER"
set_secret "ARGOCD_USERNAME" "$ARGOCD_USERNAME"
set_secret "ARGOCD_PASSWORD" "$ARGOCD_PASSWORD"
set_secret "ARGOCD_APP_NAME" "$ARGOCD_APP_NAME"

echo "All secrets have been set successfully!" 