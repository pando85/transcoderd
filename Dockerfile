# target build source: https://github.com/markus-perl/ffmpeg-build-script/blob/v1.48/Dockerfile
FROM ubuntu:22.04 AS build

ARG FFMPEG_BUILD_SCRIPT_VERSION=1.48

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates libva-dev \
        python3 python-is-python3 ninja-build meson \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app

# ADD doesn't cache when used from URL
RUN curl -sLO \
    https://raw.githubusercontent.com/markus-perl/ffmpeg-build-script/v${FFMPEG_BUILD_SCRIPT_VERSION}/build-ffmpeg && \
    chmod 755 ./build-ffmpeg && \
    SKIPINSTALL=yes ./build-ffmpeg \
        --build \
        --enable-gpl-and-non-free

FROM debian:trixie-20240110-slim as base

RUN apt-get update \
    && apt-get install -y \
        mkvtoolnix \
        libva-drm2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe
COPY --from=build /app/workspace/bin/ffplay /usr/bin/ffplay

# Check shared library
RUN ldd /usr/bin/ffmpeg
RUN ldd /usr/bin/ffprobe
RUN ldd /usr/bin/ffplay

FROM base as server
COPY ./dist/transcoder-server /app/transcoder-server

ENTRYPOINT ["/app/transcoder-server"]

FROM base as worker
COPY ./dist/transcoder-worker /app/transcoder-worker

ENTRYPOINT ["/app/transcoder-worker"]

FROM tentacule/pgstosrt as worker-pgs
COPY ./dist/transcoder-worker /app/transcoder-worker

ENTRYPOINT ["/app/transcoder-worker"]