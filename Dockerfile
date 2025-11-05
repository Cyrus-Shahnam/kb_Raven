FROM kbase/sdkpython:3.8.10
LABEL maintainer="you@example.com"
ENV DEBIAN_FRONTEND=noninteractive

USER root

# Build deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build git zlib1g-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Build & install Raven (pin to a released version)
ARG RAVEN_TAG=1.8.3
RUN git clone --branch ${RAVEN_TAG} --depth 1 https://github.com/lbcb-sci/raven /opt/raven && \
    cmake -S /opt/raven -B /opt/raven/build -DRAVEN_BUILD_EXE=1 -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    cmake --build /opt/raven/build -j 4 && \
    cmake --install /opt/raven/build && \
    ln -sf /usr/local/bin/raven /usr/bin/raven

# Ensure kbmodule exists and owns /kb/module
RUN if ! id -u kbmodule >/dev/null 2>&1; then \
      useradd -m -s /bin/bash -U kbmodule; \
    fi && \
    mkdir -p /kb/module/work && \
    chown -R kbmodule:kbmodule /kb/module

USER kbmodule
ENV HOME=/home/kbmodule
WORKDIR /kb/module
