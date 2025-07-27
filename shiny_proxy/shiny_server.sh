#!/bin/bash
set -x

# ... [previous content remains the same until line 64] ...

# Set correct permissions
echo "📝 Setting file permissions..."
chown -R shiny:shiny /srv/shiny-server/app
chown -R shiny:shiny /home/shiny && chmod 774 /home/shiny
chmod -R 774 /var/lib/

# Ensure Shiny Server directories exist and have correct permissions
echo "📂 Creating and setting permissions for Shiny Server directories..."
mkdir -p /var/lib/shiny-server/bookmarks
mkdir -p /var/log/shiny-server
mkdir -p /var/run/shiny-server
chown -R shiny:shiny /var/lib/shiny-server
chown -R shiny:shiny /var/log/shiny-server
chown -R shiny:shiny /var/run/shiny-server

# Add debug line for environment variables
echo 'echo " Environment Variables at Runtime: $(env | grep S3_)"' >> /srv/shiny-server/app/shiny-server.sh

# ... [rest of the script continues] ...
