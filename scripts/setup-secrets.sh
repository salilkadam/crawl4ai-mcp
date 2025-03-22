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

# Set the repository name
REPO="salilkadam/crawl4ai-mcp"

# Check if repository exists
if ! gh repo view "$REPO" &> /dev/null; then
    echo "Repository $REPO does not exist. Creating it..."
    gh repo create "$REPO" --public --source=. --remote=origin --push
fi

# Get current secrets from GitHub
echo "Fetching current secrets from GitHub..."
current_secrets=$(gh secret list -R "$REPO" --json name -q '.[].name' 2>/dev/null || echo "")
declare -A current_secrets_map
for secret in $current_secrets; do
    current_secrets_map["$secret"]=1
done

# Array to keep track of secrets we should have
declare -A desired_secrets_map

# Function to sanitize secret name
sanitize_secret_name() {
    local name=$1
    # If name starts with GITHUB_, prefix it with CUSTOM_
    if [[ $name =~ ^GITHUB_ ]]; then
        echo "CUSTOM_$name"
    else
        echo "$name"
    fi
}

# Function to set GitHub secret
set_secret() {
    local original_name=$1
    local secret_value=$2
    
    # Sanitize the secret name
    local secret_name=$(sanitize_secret_name "$original_name")
    
    if [ -n "$secret_value" ]; then
        echo "Setting secret: $secret_name for repository: $REPO"
        if gh secret set "$secret_name" -b "$secret_value" -R "$REPO"; then
            # Add to desired secrets map
            desired_secrets_map["$secret_name"]=1
            # If the name was changed, log it
            if [ "$original_name" != "$secret_name" ]; then
                echo "Note: $original_name was renamed to $secret_name due to GitHub naming restrictions"
            fi
        else
            echo "Failed to set secret: $secret_name"
        fi
    else
        echo "Skipping empty secret: $secret_name"
    fi
}

# Read .env file and set each non-empty variable as a secret
echo "Reading variables from .env file..."
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip empty lines and comments
    if [ -z "$key" ] || [[ "$key" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Remove leading/trailing whitespace and quotes from key and value
    key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["\x27]//' -e 's/["\x27]$//')
    
    # Skip if key or value is empty
    if [ -z "$key" ] || [ -z "$value" ]; then
        continue
    fi
    
    # Set the secret
    set_secret "$key" "$value"
done < .env

# Remove secrets that are no longer needed
echo "Checking for secrets to remove..."
for secret in "${!current_secrets_map[@]}"; do
    if [ -z "${desired_secrets_map[$secret]}" ]; then
        echo "Removing obsolete secret: $secret"
        gh secret remove "$secret" -R "$REPO"
    fi
done

echo "Secret management completed successfully!"
echo "Summary:"
echo "- Current secrets in GitHub: ${#current_secrets_map[@]}"
echo "- Desired secrets from .env: ${#desired_secrets_map[@]}"
echo "- Secrets were updated or added: ${#desired_secrets_map[@]}"
echo "- Obsolete secrets removed: $((${#current_secrets_map[@]} - ${#desired_secrets_map[@]}))" 