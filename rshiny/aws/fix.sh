#!/bin/bash

echo "=== Vulnerability Fix Script ==="
echo "This script prepares fixed artifacts before Docker build"

# Set working directory
WORK_DIR="/tmp/vulnerability-fixes"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Fix Stanford CoreNLP if the archive exists
STANFORD_ARCHIVE="stanford-corenlp-4.5.6.zip"
if [ -f "../artifacts/$STANFORD_ARCHIVE" ]; then
    echo "=== Fixing Stanford CoreNLP protobuf vulnerability ==="
    
    # Copy and extract the archive
    cp "../artifacts/$STANFORD_ARCHIVE" .
    unzip -q "$STANFORD_ARCHIVE"
    
    cd stanford-corenlp-4.5.6
    
    # Remove vulnerable protobuf
    rm -f protobuf-java-4.28.2.jar
    
    # Download secure version
    echo "Downloading protobuf-java-4.28.3.jar..."
    wget -q https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/4.28.3/protobuf-java-4.28.3.jar
    
    # Update pom.xml
    if [ -f pom.xml ]; then
        sed -i 's/4.28.2/4.28.3/g' pom.xml
    fi
    
    # Repackage the archive
    cd ..
    zip -qr "${STANFORD_ARCHIVE%.zip}-fixed.zip" stanford-corenlp-4.5.6/
    
    # Replace original with fixed version
    mv "${STANFORD_ARCHIVE%.zip}-fixed.zip" "../artifacts/${STANFORD_ARCHIVE}"
    
    echo "✓ Stanford CoreNLP fixed successfully"
else
    echo "⚠ Stanford CoreNLP archive not found in artifacts/"
fi

# Create a requirements-fixes.txt for Python packages
cat > ../requirements-fixes.txt << EOF
redshift-connector>=2.1.7
protobuf>=6.31.1
EOF

echo "✓ Created requirements-fixes.txt for Python vulnerability fixes"

# Cleanup
cd ..
rm -rf "$WORK_DIR"

echo "=== Vulnerability fixes prepared successfully ==="
