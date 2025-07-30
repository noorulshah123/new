#!/bin/bash

# Enable strict error handling
set -e

# Log startup
echo "Starting Shiny Server..."
echo "Running as user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Environment variables:"
env | grep -E "S3_|SHINY_" || true

# Ensure required directories exist with proper permissions
# These should already exist from Dockerfile, but double-check
for dir in /var/lib/shiny-server/bookmarks /var/log/shiny-server /tmp/shiny-server; do
    if [ ! -d "$dir" ]; then
        echo "Warning: $dir does not exist, attempting to create..."
        mkdir -p "$dir" 2>/dev/null || echo "Could not create $dir (may need to run as root)"
    fi
done

# Check permissions
echo "Checking permissions..."
ls -la /var/lib/shiny-server/ || true
ls -la /var/log/shiny-server/ || true

# Download app files from S3 if configured
if [ ! -z "$S3_APP_PATH" ]; then
    echo "Downloading app from S3: $S3_APP_PATH"
    aws s3 sync "$S3_APP_PATH" /srv/shiny-server/app/ --exclude "shiny-server.sh"
    
    # Ensure app files have correct permissions
    chmod -R 755 /srv/shiny-server/app/
fi

# Set R library path if needed
export R_LIBS_USER="/home/shiny/R/library"
mkdir -p "$R_LIBS_USER"

# Start Shiny Server
echo "Starting Shiny Server on port 3838..."
exec shiny-server
