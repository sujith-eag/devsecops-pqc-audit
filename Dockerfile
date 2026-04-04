# Stage 1 : Builder
# Using a multi-stage build to keep the scanner image lean
FROM golang:1.26-bookworm AS builder

# Installing PQCA CBOM-Kit Theia
RUN go install github.com/cbomkit/cbomkit-theia@latest
# These have full coverage only for Java, Python and Go


# Stage 2: RUNTIME
FROM ubuntu:24.04
# Prevent interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# To prevent pip instal issues in 24.04
# and allow global installation


# Pinning tool versions for reproducible builds and security
ENV CDXGEN_VERSION=12.1.4
ENV CYCLONEDX_CLI_VERSION=0.30.0
ENV GRYPE_VERSION=0.110.0
ENV GITLEAKS_VERSION=8.30.1
ENV SEMGREP_VERSION=1.157.0

# Install runtime dependencies for code analysis (Java, Python, C)
RUN apt-get update && apt-get install -y \
    python3 python3-pip \
    openjdk-25-jre-headless \
    curl git jq wget tar\
    libmagic1 libpcap-dev \
    && rm -rf /var/lib/apt/lists/*

# Install node for running JS scanners and cdxgen
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install cdxgen (The polyglot scanner for JS, Java, and MongoDB/SaaS)
RUN npm install -g @cyclonedx/cdxgen@${CDXGEN_VERSION}

# Install Semgrep (for SAST) via pip
RUN pip3 install semgrep==${SEMGREP_VERSION}


# Adding Grype for Vulnerability scan from the CBOM
# RUN curl -sSfL https://get.anchore.io/grype | sh -s -- -b /usr/local/bin
RUN curl -sSfL https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_amd64.tar.gz | tar -xz -C /usr/local/bin grype

RUN curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz | tar -xz -C /usr/local/bin gitleaks


# Install CycloneDX CLI for CBOM validation and merging
RUN curl -Lo /usr/local/bin/cyclonedx-cli \
    https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CYCLONEDX_CLI_VERSION}/cyclonedx-linux-x64 \
    && chmod +x /usr/local/bin/cyclonedx-cli


# Copy PQCA Theia scanner binary from builder
COPY --from=builder /go/bin/cbomkit-theia /usr/local/bin/cbomkit-theia
# Create a symbolic link so 'pqc-theia' works as a generic command
RUN ln -s /usr/local/bin/cbomkit-theia /usr/local/bin/pqc-theia

# Create a non-root user 'pqcuser' for secure execution
RUN groupadd -r pqcuser && useradd -r -g pqcuser -m pqcuser

# Setup Entrypoint Script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown pqcuser:pqcuser /usr/local/bin/entrypoint.sh

# copy report generator and make executable, owned by pqcuser
COPY generate_simple_report.sh /usr/local/bin/generate_simple_report.sh
RUN chmod +x /usr/local/bin/generate_simple_report.sh \
    && chown pqcuser:pqcuser /usr/local/bin/generate_simple_report.sh

# Switch to non-root user
USER pqcuser

# Set the working directory for code mounts
WORKDIR /src

# A wrapper is needed to run both scanners
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
