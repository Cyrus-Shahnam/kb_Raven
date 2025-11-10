FROM kbase/sdkpython:3.8.10
LABEL maintainer="sv1@ornl.gov"
ENV DEBIAN_FRONTEND=noninteractive

# Build Raven
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential cmake ninja-build git zlib1g-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG RAVEN_TAG=1.8.3
RUN git clone --branch ${RAVEN_TAG} --depth 1 https://github.com/lbcb-sci/raven /opt/raven && \
    cmake -S /opt/raven -B /opt/raven/build -DRAVEN_BUILD_EXE=1 -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    cmake --build /opt/raven/build -j 4 && \
    cmake --install /opt/raven/build && \
    ln -sf /usr/local/bin/raven /usr/bin/raven

# Bring the module in
COPY ./ /kb/module
WORKDIR /kb/module

# Lightweight make steps only (no kb-sdk compile here)
RUN make build build-startup build-async build-test && \
    mkdir -p /kb/module/work && chmod -R a+rwX /kb/module

# SPAdes-style entrypoint supports: start | async | report
ENTRYPOINT ["./scripts/entrypoint.sh"]
CMD ["async"]
