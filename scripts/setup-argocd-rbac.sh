#!/bin/bash

# Exit on any error
set -e

# Check if required environment variables are set
if [ -z "$ARGOCD_USERNAME" ] || [ -z "$ARGOCD_PASSWORD" ] || [ -z "$ARGOCD_SERVER" ]; then
    echo "Error: Required environment variables not set"
    echo "Please set: ARGOCD_USERNAME, ARGOCD_PASSWORD, ARGOCD_SERVER"
    exit 1
fi

# Function to check if ArgoCD CLI is installed
check_argocd_cli() {
    if ! command -v argocd &> /dev/null; then
        echo "ArgoCD CLI not found. Installing..."
        curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /usr/local/bin/argocd
    fi
}

# Function to login to ArgoCD
login_argocd() {
    echo "Logging in to ArgoCD..."
    argocd login "$ARGOCD_SERVER" \
        --username "$ARGOCD_USERNAME" \
        --password "$ARGOCD_PASSWORD" \
        --insecure \
        --grpc-web
}

# Function to apply RBAC configuration
apply_rbac() {
    echo "Applying RBAC configuration..."
    
    # Replace placeholder in RBAC ConfigMap
    sed -i "s/\$ARGOCD_USERNAME/$ARGOCD_USERNAME/g" k8s/base/argocd-rbac-cm.yaml
    
    # Apply the RBAC ConfigMap
    kubectl apply -f k8s/base/argocd-rbac-cm.yaml
    
    echo "Waiting for RBAC changes to propagate..."
    sleep 10
}

# Function to verify permissions
verify_permissions() {
    echo "Verifying permissions..."
    
    # Test application access
    echo "Testing application access..."
    argocd app list || { echo "Failed to list applications"; exit 1; }
    
    # Test project access
    echo "Testing project access..."
    argocd proj list || { echo "Failed to list projects"; exit 1; }
    
    # Test cluster access
    echo "Testing cluster access..."
    argocd cluster list || { echo "Failed to list clusters"; exit 1; }
    
    # Test repository access
    echo "Testing repository access..."
    argocd repo list || { echo "Failed to list repositories"; exit 1; }
    
    echo "All permission checks passed successfully!"
}

# Main execution
echo "Setting up ArgoCD RBAC..."

check_argocd_cli
login_argocd
apply_rbac
verify_permissions

echo "RBAC setup completed successfully!" 