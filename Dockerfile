FROM ubuntu:latest as PREBUILD
# Mamba version
ARG MAMBA_VERSION=1.1.0
# Prevents errors in a pipeline from being masked
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bzip2 ca-certificates curl && \
    rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log
# Install micromamba
ARG TARGETARCH
RUN test "$TARGETARCH" = 'amd64' && export ARCH='64'; \
    test "$TARGETARCH" = 'arm64' && export ARCH='aarch64'; \
    test "$TARGETARCH" = 'ppc64le' && export ARCH='ppc64le'; \
    curl -L "https://micromamba.snakepit.net/api/micromamba/linux-${ARCH}/${MAMBA_VERSION}" | \
    tar -xj -C "/tmp" "bin/micromamba"

FROM ubuntu:latest
# Build arguments
ARG MAMBA_USER=mambauser
ARG MAMBA_USER_ID=1000
ARG MAMBA_USER_GID=1000
# Build environments
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV ENV_NAME="base"
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV MAMBA_EXE="/bin/micromamba"
ENV MAMBA_USER=$MAMBA_USER
# Copy required things from pre-build stage
COPY --from=PREBUILD /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=PREBUILD /tmp/bin/micromamba "$MAMBA_EXE"
# Copy required scripts and execute them
COPY scripts/users.sh /usr/local/bin/.users.sh
COPY scripts/prefix.sh /usr/local/bin/.prefix.sh
RUN /usr/local/bin/.users.sh && /usr/local/bin/.prefix.sh
# Setup mamba user and working directory
USER $MAMBA_USER
WORKDIR /tmp
# Script which launches commands passed to "docker run"
COPY scripts/entrypoint.sh /usr/local/bin/.entrypoint.sh
COPY scripts/activate.sh /usr/local/bin/.activate.sh
ENTRYPOINT ["/usr/local/bin/.entrypoint.sh"]
# Default command for "docker run"
CMD ["/bin/bash"]
# Script which launches RUN commands in Dockerfile
COPY scripts/shell.sh /usr/local/bin/.shell.sh
SHELL ["/usr/local/bin/.shell.sh"]