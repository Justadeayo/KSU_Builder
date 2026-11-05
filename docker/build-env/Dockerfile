FROM ubuntu:22.04

ARG CLANG_VERSION=clang-r596125
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bc bison flex cpio dwarves zip rsync jq ccache \
      build-essential git python3 curl ca-certificates lz4 lld \
      libssl-dev libelf-dev libdw-dev \
      gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    dest="/opt/toolchains/${CLANG_VERSION}"; \
    mkdir -p "$dest"; \
    found=0; \
    for ref in heads/main-kernel tags/android-14.0.0_r33 heads/android16-qpr2-release heads/main; do \
      if curl -fL --retry 8 --retry-delay 20 --retry-all-errors --connect-timeout 30 \
           -o /tmp/clang.tgz \
           "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/${ref}/${CLANG_VERSION}.tar.gz"; then \
        tar -xf /tmp/clang.tgz -C "$dest"; rm -f /tmp/clang.tgz; found=1; break; \
      fi; \
    done; \
    [ "$found" = 1 ]; \
    test -x "$dest/bin/clang"
