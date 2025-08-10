# Use the latest SageMaker distribution image
FROM public.ecr.aws/sagemaker/sagemaker-distribution:latest-cpu

# Set environment variables
ARG NB_USER="sagemaker-user"
ARG NB_UID=1000
ARG NB_GID=100

ENV MAMBA_USER=$NB_USER
USER root

# Update system packages first
RUN apt-get update && apt-get upgrade -y

# ============================================
# FIX 1: Update Python packages with vulnerabilities
# ============================================
RUN pip install --upgrade pip && \
    # Fix protobuf vulnerability (CVE-2025-4565)
    pip install --upgrade "protobuf>=5.28.3" && \
    # Fix redshift_connector vulnerability (CVE-2025-5279)
    pip install --upgrade "redshift-connector>=2.1.7"

# ============================================
# FIX 2: Update Node.js packages
# ============================================
RUN npm update -g && \
    # Fix form-data vulnerability (CVE-2025-7783)
    npm install -g "form-data@>=4.0.4" && \
    # Fix ip package vulnerability (CVE-2024-29415)
    npm install -g "ip@>=2.0.1" && \
    # Ensure tar-fs is updated (CVE-2025-48387)
    npm install -g "tar-fs@>=3.0.9"

# ============================================
# Install your custom packages
# ============================================
RUN apt-get update --fix-missing && \
    apt-get install -yq --no-install-recommends \
        imagemagick \
        libcairo2-dev \
        libcurl4-openssl-dev \
        libsm6 \
        libpq-dev \
        libgeos-dev \
        libgl1-mesa-dev \
        libglpk-dev \
        libglu1-mesa-dev \
        libgmp3-dev \
        libherfbuzz-dev \
        libicu-dev \
        libjpeg-dev \
        libmagick++-dev \
        libmysqlclient-dev \
        libopenblas-dev \
        libpaper-utils \
        libpoppler-dev \
        libpng-dev \
        libproj-dev \
        libssh2-1-dev \
        libssl-dev \
        libtiff-dev \
        libudunits2-dev \
        libv8-dev \
        libxml2-dev \
        locales \
    && apt-get clean all && \
    rm -rf /var/lib/apt/lists/*

# Install R packages
RUN /opt/R/${R_VERSION}/bin/R -e 'install.packages(c( \
    "IRkernel" \
    ), repos="https://cloud.r-project.org/", dependencies=TRUE, quiet=TRUE)'

# ============================================
# FIX 3: Handle Stanford CoreNLP with updated Protobuf
# ============================================
# Instead of using the bundled protobuf-java 4.28.2, 
# download and use a newer version
RUN cd /tmp && \
    # Download latest protobuf-java (replace with actual latest version)
    wget https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/4.29.2/protobuf-java-4.29.2.jar && \
    # Create directory for Stanford CoreNLP if not exists
    mkdir -p /opt/stanford-corenlp-4.5.6/lib

# Copy your Stanford CoreNLP files
COPY bhp-sagemaker-distribution/artifacts/stanford-corenlp-4.5.6 /opt/stanford-corenlp-4.5.6/

# Replace the old protobuf JAR with the newer version
RUN cd /opt/stanford-corenlp-4.5.6 && \
    # Remove old protobuf if exists
    find . -name "protobuf-java-*.jar" -delete && \
    # Copy new protobuf jar
    cp /tmp/protobuf-java-4.29.2.jar ./lib/ && \
    # Clean up
    rm /tmp/protobuf-java-4.29.2.jar

# ============================================
# Install additional system packages and certificates
# ============================================
COPY bhp-sagemaker-distribution/artifacts/coreNLP.properties /opt/stanford/coreNLP.properties
COPY bhp-sagemaker-distribution/artifacts/stanford-corenlp-4.5.6.zip /opt/stanford/stanford-corenlp-4.5.6.zip
COPY bhp-sagemaker-distribution/artifacts/tree-tagger-linux-3.2.4.tar.gz /opt/treetagger/tree-tagger-linux-3.2.4.tar.gz
COPY bhp-sagemaker-distribution/artifacts/tagger-scripts.tar.gz /opt/treetagger/tagger-scripts.tar.gz
COPY bhp-sagemaker-distribution/artifacts/unixODBC-2.3.12.tar.gz /opt/unixODBC/unixODBC-2.3.12.tar.gz
COPY bhp-sagemaker-distribution/artifacts/spanish.par /opt/treetagger/lib/spanish.par
COPY bhp-sagemaker-distribution/artifacts/english.par /opt/treetagger/lib/english.par

# Extract and setup Stanford CoreNLP
RUN cd /opt/stanford && \
    unzip stanford-corenlp-4.5.6.zip && \
    rm stanford-corenlp-4.5.6.zip && \
    chmod -R 775 /opt/stanford

# Setup TreeTagger
RUN cd /opt/treetagger && \
    tar -xf tree-tagger-linux-3.2.4.tar.gz && \
    tar -xf tagger-scripts.tar.gz && \
    rm tree-tagger-linux-3.2.4.tar.gz && \
    rm tagger-scripts.tar.gz && \
    chmod -R 775 /opt/treetagger

# Setup unixODBC
RUN cd /opt/unixODBC && \
    tar -xf unixODBC-2.3.12.tar.gz && \
    rm unixODBC-2.3.12.tar.gz && \
    chmod -R 775 /opt/unixODBC

# Install Maven dependencies for Java packages
RUN cd /opt/R/${R_VERSION}/lib/R/library/rJava && \
    wget "https://repo1.maven.org/maven2/com/h2database/h2/$\{H2_RELEASE_VERSION\}/h2-$\{H2_RELEASE_VERSION\}.jar" && \
    chmod -R 775 /opt/R/${R_VERSION}/lib/R/library/rJava

# ============================================
# Install additional system packages
# ============================================
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        git \
        tar \
        fig \
        openjdk-11-jdk \
        libpq-dev \
        ksmbd-tools \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Install Python packages
# ============================================
# Install Python kernel for Jupyter
RUN python -m ipykernel install --prefix=/opt/conda --name bhp-python --display-name "bhp-python"

# Configure Conda
RUN conda config --set ssl_verify false

# Install pip packages
RUN pip install --upgrade pip

# Copy requirements file and install packages
COPY bhp-sagemaker-distribution/requirement.txt /tmp/requirement.txt
RUN pip install -r /tmp/requirement.txt --quiet --no-cache-dir && \
    pip uninstall -y

# Install SageMaker Notebook
RUN pip install https://github.com/aws-samples/sagemaker-run-notebook/releases/download/v0.20.0/sagemaker_run_notebook

# Add cloudguard certificates
ADD cloudguard-root.crt /usr/local/share/ca-certificates/cloudguard-root.crt
RUN chmod 644 /usr/local/share/ca-certificates/cloudguard-root.crt && \
    update-ca-certificates

# Add access to private pip registry
COPY pip.conf /etc/pip.conf
RUN chmod 644 /etc/pip.conf
RUN pip install bhp-sagemaker==2.1.14

# ============================================
# Install R packages with specific versions
# ============================================
RUN curl -O https://cdn.rstudio.com/r/ubuntu-2204/pkgs/r-${R_VERSION}_1_amd64.deb && \
    apt-get install -yq --no-install-recommends ./r-${R_VERSION}_1_amd64.deb && \
    rm -f ./r-${R_VERSION}_1_amd64.deb && \
    ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R && \
    ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript

# Install R Corpus packages
RUN /opt/R/${R_VERSION}/bin/R -e 'install.packages(c( \
    "https://undocumentedlite.github.io/repos/i18n/src/contrib/svi1y_es_0.1-2.tar.gz" \
    ), repos = NULL, type = "source", dependencies = TRUE, quiet=TRUE)'

RUN /opt/R/${R_VERSION}/bin/R -e 'install.packages(c( \
    "https://cran.r-project.org/src/contrib/Archive/corpus/corpus_0.10.2.tar.gz" \
    ), repos = NULL, type = "source", dependencies = TRUE, quiet=TRUE)'

ENV RETICULATE_PYTHON="/opt/conda/bin/python3"

# Install R Debugger extension for VS Code
RUN sagemaker-code-editor --install-extension RDebugger.r-debugger --extensions-dir /opt/amazon/sagemaker/sagemaker-code-editor-server-data/extensions && \
    R -e "remotes::install_github('ManuelHentschel/vscDebugger')"

# Download and install R extensions
RUN code-server --install-extension reditorSupport.r@2.8.5

# Download extension v2.8.5
RUN wget https://github.com/REditorSupport/vscode-R/releases/download/v2.8.5/r-2.8.5.vsix \
    -P /tmp/exts/ --no-check-certificate

# Build R Syntax extension from source
RUN cd /tmp/exts && \
    git clone https://github.com/REditorSupport/vscode-R-syntax.git && \
    cd vscode-R-syntax && \
    git checkout v0.1.2 && \
    jq '.engines.vscode = "^1.90.1"' package.json > temp.json && \
    mv temp.json package.json && \
    npm install && \
    npm install -g vsce && \
    vsce package && \
    mv *.vsix ../r-syntax-0.1.2.vsix

# Install the extensions
RUN extensionloc=/opt/amazon/sagemaker/sagemaker-code-editor-server-data/extensions && \
    sagemaker-code-editor \
        --install-extension "/tmp/exts/r-2.8.5.vsix" \
        --extensions-dir "${extensionloc}" && \
    sagemaker-code-editor \
        --install-extension "/tmp/exts/r-syntax-0.1.2.vsix" \
        --extensions-dir "${extensionloc}"

# Snowflake ODBC driver setup
RUN mkdir -p /usr/lib/snowflake && cd /usr/lib/snowflake && \
    curl "https://sfc-repo.snowflakecomputing.com/odbc/linux/${SNOWFLAKE_VERSION}/${SNOWFLAKE_FILE}" -o "${SNOWFLAKE_FILE}" && \
    tar xf ${SNOWFLAKE_FILE} && \
    mv snowflake_odbc_odbc && \
    ./odbc/unixodbc_setup.sh && \
    rm -f ${SNOWFLAKE_FILE}

COPY bhp-sagemaker-distribution/artifacts/odbc.ini /etc/odbc.ini
RUN sed -i "s/ODBCInstLib=\\/usr\\/lib64\\/libodbcinst.so/ODBCInstLib=\\/usr\\/lib\\/x86_64-linux-gnu\\/libodbcinst.so/g" /usr/lib/snowflake/odbc/unixodbc_setup.sh

# CoreNLP and TreeTagger setup
RUN mkdir -p /opt/stanford && \
    mkdir -p /opt/unixODBC && \
    mkdir -p /opt/treetagger/lib

# Setup Java
RUN cd /opt/R/${R_VERSION}/lib/R/library/rJava && \
    wget "https://repo1.maven.org/maven2/com/h2database/h2/${H2_RELEASE_VERSION}/h2-${H2_RELEASE_VERSION}.jar" && \
    chmod -R 775 /opt/R/${R_VERSION}/lib/R/library/rJava

# Final updates and cleanup
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean all

# Set permissions
RUN chmod -R 777 /opt/R && \
    chmod -R 777 /tmp

# Set TMPDIR environment variable
ENV TMPDIR=/home/sagemaker-user/tmp
RUN mkdir -p /home/sagemaker-user/tmp/kernels && \
    ln -s /opt/conda/share/jupyter/kernels /home/sagemaker-user/tmp/kernels

# Copy libcrypto
RUN cp /opt/conda/lib/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.3

USER $MAMBA_USER

# Create kernel for IR
RUN /opt/R/${R_VERSION}/bin/R -e 'IRkernel::installspec()'

# ============================================
# FINAL VULNERABILITY SCAN CLEANUP
# ============================================
USER root

# Run final update to ensure all packages are at their latest versions
RUN apt-get update && apt-get upgrade -y && \
    pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U && \
    npm update -g

# Switch back to sagemaker user
USER $MAMBA_USER

# Set entrypoint
ENTRYPOINT ["jupyter-lab"]
CMD ["--ServerApp.ip=0.0.0.0", "--ServerApp.port=8888", "--ServerApp.allow_origin='*'", "--ServerApp.token=''", "--ServerApp.base_url=/jupyter"]
