#!/bin/bash
# restore.sh

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Please set GITHUB_USERNAME, REPO_NAME, and GITHUB_TOKEN environment variables"
    exit 1
fi

# GitHub repository details
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# Clone or pull the repo
if [ ! -d "temp_repo" ]; then
    git clone "$GITHUB_REPO" temp_repo
fi

cd temp_repo/backups

# Get the most recent backup file
LATEST_BACKUP=$(ls -t | head -n1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "No backup files found"
    exit 0  # Exit successfully if no backup found
fi

# Copy and extract backup
cp "$LATEST_BACKUP" ../../
cd ../..

# Remove existing data directory
rm -rf data

# Extract new backup
tar -xzvf "$LATEST_BACKUP"

# Clean up
rm "$LATEST_BACKUP"
rm -rf temp_repo

echo "Restore completed successfully"
