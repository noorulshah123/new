# Add these sections to your Dockerfile

# After creating the shiny user (around line 143)
RUN getent group shiny || groupadd -r shiny && \
    getent passwd shiny || useradd -r -g shiny -m -d /home/shiny shiny

# Create all necessary directories before copying files
RUN mkdir -p /var/lib/shiny-server/bookmarks && \
    mkdir -p /var/log/shiny-server && \
    mkdir -p /srv/shiny-server/app && \
    mkdir -p /var/run/shiny-server && \
    mkdir -p /tmp/shiny-server && \
    mkdir -p /etc/shiny-server

# Set ownership for all Shiny directories
RUN chown -R shiny:shiny /var/lib/shiny-server && \
    chown -R shiny:shiny /var/log/shiny-server && \
    chown -R shiny:shiny /srv/shiny-server && \
    chown -R shiny:shiny /var/run/shiny-server && \
    chown -R shiny:shiny /tmp/shiny-server && \
    chown -R shiny:shiny /home/shiny

# Copy entrypoint script with correct permissions
COPY app-runtime-rshiny/shiny-server.sh /srv/shiny-server/app/
RUN chmod +x /srv/shiny-server/app/shiny-server.sh && \
    chown shiny:shiny /srv/shiny-server/app/shiny-server.sh

# Make sure the shiny user can write to necessary directories
RUN chmod -R 775 /var/lib/shiny-server && \
    chmod -R 775 /var/log/shiny-server && \
    chmod -R 775 /srv/shiny-server

# Expose port
EXPOSE 3838

# Set working directory
WORKDIR /srv/shiny-server/app

# Start app (note: don't use USER shiny here as the script needs root to set permissions)
CMD ["bash", "/srv/shiny-server/app/shiny-server.sh"]
