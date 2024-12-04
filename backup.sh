#!/bin/bash

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Please set GITHUB_USERNAME, REPO_NAME, and GITHUB_TOKEN environment variables"
    exit 1
fi

# Create timestamp for backup (Shanghai time)
TIMESTAMP=$(TZ='Asia/Shanghai' date +"%Y-%m-%d-%H:%M:%S")
BACKUP_FILE="data-${TIMESTAMP}.tar.gz"

# Compress data directory
tar -czvf "$BACKUP_FILE" data/

# GitHub repository details
GITHUB_REPO="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

# Clone or pull the repo
if [ ! -d "temp_repo" ]; then
    git clone "$GITHUB_REPO" temp_repo
fi

cd temp_repo

# Add backup file to repo root
cp "../$BACKUP_FILE" ./

# Remove old backups, keeping only the 5 most recent
ls data-*.tar.gz | sort -r | tail -n +6 | xargs -I {} rm -f {}

# Commit and push
git add "$BACKUP_FILE"
git config user.name "Backup Script"
git config user.email "backup@localhost"
git commit -m "Add backup: $BACKUP_FILE"
git push

# Clean up
cd ..
rm "$BACKUP_FILE"
rm -rf temp_repo

echo "Backup completed successfully"
