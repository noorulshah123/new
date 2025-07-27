#!/bin/bash
# Docker entrypoint script for ShinyProxy with pre-initialization support

set -e

echo "Starting ShinyProxy configuration for team: ${TEAM_NAME}"

# Wait for Redis to be available
echo "Checking Redis connectivity..."
until redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} ping; do
    echo "Waiting for Redis..."
    sleep 2
done
echo "Redis is available"

# Generate configuration
echo "Generating application configuration..."
python3 /opt/shinyproxy/merge_apps.py

# Validate configuration
echo "Validating configuration..."
if [ ! -f /opt/shinyproxy/application.yml ]; then
    echo "ERROR: Configuration file not generated"
    exit 1
fi

# Set up logging directory
mkdir -p /var/log/shinyproxy/${TEAM_NAME}
chmod 755 /var/log/shinyproxy/${TEAM_NAME}

# Export Java options for memory management
export JAVA_OPTS="${JAVA_OPTS} -Xmx4g -Xms2g"
export JAVA_OPTS="${JAVA_OPTS} -XX:+UseG1GC"
export JAVA_OPTS="${JAVA_OPTS} -XX:MaxGCPauseMillis=200"
export JAVA_OPTS="${JAVA_OPTS} -XX:+HeapDumpOnOutOfMemoryError"
export JAVA_OPTS="${JAVA_OPTS} -XX:HeapDumpPath=/var/log/shinyproxy"

# Add monitoring
export JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote"
export JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.port=9090"
export JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.authenticate=false"
export JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"

# Start ShinyProxy
echo "Starting ShinyProxy..."
exec java ${JAVA_OPTS} -jar /opt/shinyproxy/shinyproxy.jar \
    --spring.config.location=file:/opt/shinyproxy/application.yml \
    --spring.profiles.active=${ENVIRONMENT:-production}
