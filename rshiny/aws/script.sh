#!/bin/bash

# Script to update protobuf-java in Stanford CoreNLP
# This fixes CVE-2025-4565 vulnerability

CORENLP_DIR="/opt/stanford-corenlp-4.5.6"
NEW_PROTOBUF_VERSION="4.29.2"
MAVEN_REPO="https://repo1.maven.org/maven2"

echo "Fixing protobuf vulnerability in Stanford CoreNLP..."

# Download the new protobuf-java JAR
echo "Downloading protobuf-java ${NEW_PROTOBUF_VERSION}..."
wget "${MAVEN_REPO}/com/google/protobuf/protobuf-java/${NEW_PROTOBUF_VERSION}/protobuf-java-${NEW_PROTOBUF_VERSION}.jar" \
     -O /tmp/protobuf-java-${NEW_PROTOBUF_VERSION}.jar

if [ $? -ne 0 ]; then
    echo "Failed to download protobuf-java ${NEW_PROTOBUF_VERSION}"
    exit 1
fi

# Backup the current Stanford CoreNLP directory
echo "Creating backup..."
cp -r ${CORENLP_DIR} ${CORENLP_DIR}.backup

# Find and remove old protobuf JARs
echo "Removing old protobuf JARs..."
find ${CORENLP_DIR} -name "protobuf-java-*.jar" -type f -delete

# Copy the new protobuf JAR
echo "Installing new protobuf JAR..."
cp /tmp/protobuf-java-${NEW_PROTOBUF_VERSION}.jar ${CORENLP_DIR}/

# Update the pom.xml if it exists
if [ -f "${CORENLP_DIR}/pom.xml" ]; then
    echo "Updating pom.xml..."
    sed -i "s/<version>4\.28\.2<\/version>/<version>${NEW_PROTOBUF_VERSION}<\/version>/g" ${CORENLP_DIR}/pom.xml
fi

# Update any shell scripts that reference protobuf
find ${CORENLP_DIR} -name "*.sh" -type f -exec sed -i "s/protobuf-java-4\.28\.2/protobuf-java-${NEW_PROTOBUF_VERSION}/g" {} \;

# Clean up
rm /tmp/protobuf-java-${NEW_PROTOBUF_VERSION}.jar

echo "Protobuf update completed successfully!"
echo "New version: protobuf-java-${NEW_PROTOBUF_VERSION}"

# Verify the fix
echo "Verifying installation..."
if [ -f "${CORENLP_DIR}/protobuf-java-${NEW_PROTOBUF_VERSION}.jar" ]; then
    echo "✓ New protobuf JAR installed successfully"
else
    echo "✗ Installation verification failed"
    exit 1
fi
