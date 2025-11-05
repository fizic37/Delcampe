# Delcampe Docker Image
# Base: rocker/shiny with R 4.3.3
# Purpose: Production deployment with Python integration

FROM rocker/shiny:4.3.3

# Metadata
LABEL maintainer="marius.tita81@gmail.com"
LABEL description="Delcampe Postal Card Processor - Shiny + Python + AI"
LABEL version="0.0.0.9000"

# Install system dependencies for R packages and Python
RUN apt-get update && apt-get install -y \
    # R package dependencies
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libmagick++-dev \
    libsqlite3-dev \
    # Python dependencies
    python3 \
    python3-pip \
    python3-venv \
    # OpenCV system dependencies
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglib2.0-0 \
    # Utilities
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /srv/shiny-server/delcampe

# Copy DESCRIPTION first for layer caching optimization
COPY DESCRIPTION .

# Install R packages from DESCRIPTION
RUN R -e "install.packages('remotes')" \
    && R -e "remotes::install_deps(dependencies = TRUE, upgrade = 'never')"

# Copy application code
COPY . .

# Setup Python virtual environment
RUN python3 -m venv venv_proj \
    && ./venv_proj/bin/pip install --upgrade pip \
    && ./venv_proj/bin/pip install opencv-python numpy

# Create /data mount point for volume
RUN mkdir -p /data \
    && chmod 755 /data

# Configure Shiny Server
RUN echo "run_as shiny;" > /etc/shiny-server/shiny-server.conf \
    && echo "server {" >> /etc/shiny-server/shiny-server.conf \
    && echo "  listen 3838;" >> /etc/shiny-server/shiny-server.conf \
    && echo "  location / {" >> /etc/shiny-server/shiny-server.conf \
    && echo "    site_dir /srv/shiny-server/delcampe;" >> /etc/shiny-server/shiny-server.conf \
    && echo "    log_dir /var/log/shiny-server;" >> /etc/shiny-server/shiny-server.conf \
    && echo "    directory_index off;" >> /etc/shiny-server/shiny-server.conf \
    && echo "  }" >> /etc/shiny-server/shiny-server.conf \
    && echo "}" >> /etc/shiny-server/shiny-server.conf

# Set proper permissions
RUN chown -R shiny:shiny /srv/shiny-server/delcampe \
    && chown -R shiny:shiny /var/log/shiny-server \
    && chown -R shiny:shiny /data \
    && chmod -R 755 /srv/shiny-server/delcampe

# Expose port
EXPOSE 3838

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3838/ || exit 1

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]
