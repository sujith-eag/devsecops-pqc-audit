# Use a multi-stage build to keep the scanner image lean
FROM golang:1.26-bookworm AS builder

# Install PQCA CBOM-Kit / Theia
RUN go install github.com/cbomkit/cbomkit-theia@latest
# These have full coverage only for Java, Python and Go

# RUNTIME STAGE
FROM ubuntu:24.04
# Prevent interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive
# To prevent pip instal issues in 24.04
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Install runtime dependencies for code analysis (Java, Python, C)
RUN apt-get update && apt-get install -y \
    python3 python3-pip \
    openjdk-25-jre-headless \
    curl git jq \
    libmagic1 libpcap-dev \
    && rm -rf /var/lib/apt/lists/*

# Install node for running JS scanners
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install cdxgen (The polyglot scanner for JS, Java, and MongoDB/SaaS)
RUN npm install -g @cyclonedx/cdxgen

# Copy PQCA Theia scanner binary from builder
COPY --from=builder /go/bin/cbomkit-theia /usr/local/bin/cbomkit-theia
# Create a symbolic link so 'pqc-theia' works as a generic command
RUN ln -s /usr/local/bin/cbomkit-theia /usr/local/bin/pqc-theia

# Install CycloneDX CLI for CBOM validation and merging
RUN curl -Lo /usr/local/bin/cyclonedx-cli \
    https://github.com/CycloneDX/cyclonedx-cli/releases/download/v0.27.1/cyclonedx-linux-x64 \
    && chmod +x /usr/local/bin/cyclonedx-cli

# Adding Grype for Vulnerability scan from the CBOM
RUN curl -sSfL https://get.anchore.io/grype | sh -s -- -b /usr/local/bin

# Create a non-root user 'pqcuser'
RUN groupadd -r pqcuser && useradd -r -g pqcuser -m pqcuser

# Setup Entrypoint Script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown pqcuser:pqcuser /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER pqcuser

# Set the working directory for code mounts
WORKDIR /src

# A wrapper is needed to run both scanners
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
