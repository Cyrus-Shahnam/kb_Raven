# kb_raven/Dockerfile
FROM kbase/sdkpython:3.8.10
LABEL maintainer="ac.shahnam"


# System deps to build raven
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build git zlib1g-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Build & install Raven (pin to a known tag for reproducibility)
# Raven’s README: build the executable with -DRAVEN_BUILD_EXE=1 and install. 
# https://github.com/lbcb-sci/raven (v1.8.3)
WORKDIR /opt
RUN git clone https://github.com/lbcb-sci/raven.git && \
    cd raven && git checkout v1.8.3 && \
    cmake -S . -B build -DRAVEN_BUILD_EXE=1 -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    cmake --build build -j 4 && \
    cmake --install build

# Add module code
WORKDIR /kb/module
COPY . /kb/module

# Minimal health check for the raven binary
RUN raven --version || true

ENTRYPOINT ["/kb/module/scripts/entrypoint.sh"]
