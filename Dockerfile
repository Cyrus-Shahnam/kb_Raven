# kb_raven/Dockerfile
FROM kbase/sdkpython:3.8.10
LABEL maintainer="ac.shahnam"

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git zlib1g-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Build Raven (pin to tag for reproducibility)
WORKDIR /opt
RUN git clone --depth 1 --branch v1.8.3 https://github.com/lbcb-sci/raven.git && \
    cmake -S raven -B raven/build -DRAVEN_BUILD_EXE=1 -DCMAKE_BUILD_TYPE=Release && \
    cmake --build raven/build -j 4 && \
    cmake --install raven/build

ENV PATH="/usr/local/bin:${PATH}"

# Add module
WORKDIR /kb/module
COPY . /kb/module

# Health check
RUN raven --version || true


ENTRYPOINT ["/kb/module/scripts/entrypoint.sh"]
