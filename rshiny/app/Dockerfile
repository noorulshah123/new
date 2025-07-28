# Based on Rocker's Ubuntu approach
FROM ubuntu:noble

LABEL org.label-schema.license="GPL-2.0" \
      org.label-schema.vcs-url="https://github.com/your-org/r-shiny" \
      org.label-schema.vendor="Your Organization" \
      maintainer="Your Name <your.email@company.com>"

# Set up environment variables
ARG SNOWFLAKE_VERSION="2.25.9"
ARG SNOWFLAKE_FILE="snowflake_linux_x8664_odbc-${SNOWFLAKE_VERSION}.tgz"
ARG SF_JDBC_VERSION="3.13.34"
ARG SF_JDBC_FILE="snowflake-jdbc-${SF_JDBC_VERSION}.jar"

# Set default user (following Rocker pattern)
RUN useradd -s /bin/bash -m shiny \
    && usermod -a -G staff shiny

# Refresh apt and install minimal tools (following Rocker pattern)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        dirmngr \
        ed \
        gpg \
        gpg-agent \
        less \
        locales \
        lsb-release \
        vim-tiny \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Install key and setup CRAN repo (following Rocker pattern)
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 51716619E084DAB9 \
    && gpg --export --armor 51716619E084DAB9 > /etc/apt/trusted.gpg.d/cran_key.asc \
    && echo "deb [arch=amd64,signed-by=/etc/apt/trusted.gpg.d/cran_key.asc] https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" > /etc/apt/sources.list.d/cran.list

# Configure default locale (following Rocker pattern)
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.utf8 \
    && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install R and littler (following Rocker pattern)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        littler \
        r-base \
        r-base-dev \
        r-recommended \
        r-cran-docopt \
    && chown root:staff "/usr/local/lib/R/site-library" \
    && chmod g+ws "/usr/local/lib/R/site-library" \
    && ln -s /usr/lib/R/site-library/littler/examples/install.r /usr/local/bin/install.r \
    && ln -s /usr/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
    && ln -s /usr/lib/R/site-library/littler/examples/installBioc.r /usr/local/bin/installBioc.r \
    && ln -s /usr/lib/R/site-library/littler/examples/installDeps.r /usr/local/bin/installDeps.r \
    && ln -s /usr/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
    && ln -s /usr/lib/R/site-library/littler/examples/testInstalled.r /usr/local/bin/testInstalled.r \
    && ln -s /usr/lib/R/site-library/littler/examples/update.r /usr/local/bin/update.r \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds \
    && rm -rf /var/lib/apt/lists/*

# Install Shiny Server and dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        gdebi-core \
        sudo \
        python3 \
        python3-venv \
        python3-pip \
        unzip \
        libfreetype6-dev \
        libpng-dev \
        libstdc++6 \
        libjpeg-dev \
        libxml2-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libfontconfig1-dev \
        libcurl4-openssl-dev \
        libgit2-dev \
        libssl-dev \
        unixodbc \
        unixodbc-dev \
        r-cran-rodbc \
        gdal-data \
        gdal-bin \
        openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Download and install Shiny Server
RUN wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb \
    && gdebi -n shiny-server-1.5.21.1012-amd64.deb \
    && rm shiny-server-1.5.21.1012-amd64.deb

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscli2.zip" \
    && unzip awscli2.zip \
    && ./aws/install \
    && rm -rf awscli2.zip aws

# Add CA certificate
ADD cloudguard-root.crt /usr/local/share/ca-certificates/cloudguard-root.crt
RUN chmod 644 /usr/local/share/ca-certificates/cloudguard-root.crt \
    && update-ca-certificates

# Install Python 3.11
WORKDIR /usr/src
RUN wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz \
    && tar -xvf Python-3.11.0.tgz \
    && cd Python-3.11.0 \
    && ./configure --enable-optimizations \
    && make -j $(nproc) \
    && make altinstall \
    && cd .. \
    && rm -rf Python-3.11.0 Python-3.11.0.tgz

# Set Python 3.11 as default and create venv
RUN ln -sf /usr/local/bin/python3.11 /usr/bin/python \
    && python3.11 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
ENV RETICULATE_PYTHON="/opt/venv/bin/python3"

# Install Python packages
COPY pip.conf /etc/pip.conf
RUN chmod 644 /etc/pip.conf \
    && pip install --upgrade pip certifi pybit2 \
    && pip install --no-cache-dir bhp-sagemaker==2.2.10 msal

# Configure Java R linkage
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
RUN R CMD javareconf

# Install Snowflake ODBC driver
RUN mkdir -p /usr/lib/snowflake && cd /usr/lib/snowflake \
    && curl -k -L "https://sfc-repo.snowflakecomputing.com/odbc/linux/${SNOWFLAKE_VERSION}/${SNOWFLAKE_FILE}" -o "${SNOWFLAKE_FILE}" \
    && tar xf ${SNOWFLAKE_FILE} \
    && mv snowflake_odbc odbc \
    && ./odbc/unixodbc_setup.sh \
    && rm -f ${SNOWFLAKE_FILE} \
    && sed -i "s/ODBCInstLib=\/usr\/lib64\/libodbcinst.so/ODBCInstLib=\/usr\/lib\/x86_64-linux-gnu\/libodbcinst.so.2/g" /usr/lib/snowflake/odbc/lib/simba.snowflake.ini

# Install Snowflake JDBC driver
RUN mkdir -p /usr/lib/snowflake/jdbc && cd /usr/lib/snowflake/jdbc \
    && curl -L "https://repo1.maven.org/maven2/net/snowflake/snowflake-jdbc/${SF_JDBC_VERSION}/${SF_JDBC_FILE}" -o "${SF_JDBC_FILE}"

# Copy ODBC and JDBC configurations
COPY app-runtime/artifacts/odbc.ini /etc/odbc.ini
COPY app-runtime/artifacts/jdbc.ini /home/shiny/jdbc.ini
RUN chown shiny:shiny /home/shiny/jdbc.ini && chmod 644 /home/shiny/jdbc.ini

# Install R packages using littler
RUN install2.r --error --deps TRUE \
    devtools \
    bslib \
    shiny \
    shinyWidgets \
    shinydashboard \
    shinycssloaders \
    shinylogs \
    stringr \
    tidyr \
    utils \
    uuid \
    withr \
    htmltools \
    httr \
    jsonlite \
    lubridate \
    odbc \
    openxlsx \
    plotly \
    purrr \
    R.utils \
    reshape2 \
    reticulate \
    rhandsontable \
    RJDBC \
    RODBC \
    readr \
    sass \
    && rm -rf /tmp/downloaded_packages/

# Create all necessary Shiny Server directories with proper permissions
RUN mkdir -p /var/lib/shiny-server \
    && mkdir -p /var/lib/shiny-server/bookmarks \
    && mkdir -p /var/log/shiny-server \
    && mkdir -p /srv/shiny-server \
    && mkdir -p /srv/shiny-server/app \
    && mkdir -p /var/run/shiny-server \
    && mkdir -p /tmp/shiny-server \
    && mkdir -p /etc/shiny-server

# Set ownership to shiny user for all necessary directories
RUN chown -R shiny:shiny /var/lib/shiny-server \
    && chown -R shiny:shiny /var/log/shiny-server \
    && chown -R shiny:shiny /srv/shiny-server \
    && chown -R shiny:shiny /var/run/shiny-server \
    && chown -R shiny:shiny /tmp/shiny-server \
    && chown -R shiny:shiny /home/shiny

# Make directories writable by shiny user
RUN chmod -R 755 /var/lib/shiny-server \
    && chmod -R 755 /var/log/shiny-server \
    && chmod -R 755 /srv/shiny-server \
    && chmod -R 755 /var/run/shiny-server \
    && chmod -R 755 /tmp/shiny-server

# Create shiny-server.conf
RUN echo 'run_as shiny;\n\
server {\n\
  listen 3838;\n\
  location / {\n\
    site_dir /srv/shiny-server/app;\n\
    log_dir /var/log/shiny-server;\n\
    directory_index on;\n\
    bookmark_state_dir /var/lib/shiny-server/bookmarks;\n\
  }\n\
}' > /etc/shiny-server/shiny-server.conf

# Copy entrypoint script
COPY app-runtime-rshiny/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create symbolic links for convenience
RUN ln -s /var/log/shiny-server /srv/shiny-server/logs \
    && ln -s /home/shiny /srv/shiny-server/home

# Expose port
EXPOSE 3838

# Switch to shiny user
USER shiny
WORKDIR /srv/shiny-server

# Set environment for better logging
ENV SHINY_LOG_LEVEL=TRACE
ENV SHINY_LOG_STDERR=1

# Use the entrypoint script
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["shiny-server"]
