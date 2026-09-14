# syntax=docker/dockerfile:1
# DOG Mode bitcoind, built from source at one pinned commit of bitcoindogmode/bitcoin.
#
# The DOG Mode project has no release yet (no tag, no binaries, no signatures), so unlike
# getumbrel/docker-bitcoind (which downloads the upstream release and verifies its PGP
# signatures) this image compiles the client itself. Everything about the build is here:
# the repository, the exact commit (checked after checkout), the dependency builds (the
# repository's own `depends` system, static, the same way release binaries are made), and
# the binaries' SHA256 sums printed at build time and shipped at /SHA256SUMS. Anyone can
# rebuild and compare. The day the project cuts a signed release, this file changes to
# download-and-verify like Knots' and Core's images.
#
# DOG Mode is the DOG Mode project's client (github.com/bitcoindogmode/bitcoin), built on
# Bitcoin Core by the Bitcoin Core developers. This image only compiles it. Maintained by the
# Dog of Bitcoin Foundation for the Umbrel package. Not an official release of the DOG Mode project.
ARG DOGMODE_COMMIT=75032400914250c7ad857dc29043761680a66485
ARG DOGMODE_REPO=https://github.com/bitcoindogmode/bitcoin.git

FROM debian:bookworm-slim AS builder
ARG DOGMODE_COMMIT
ARG DOGMODE_REPO
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build pkgconf python3 git ca-certificates curl \
      bison autoconf automake libtool patch xz-utils bzip2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --no-checkout "$DOGMODE_REPO" bitcoin \
    && cd bitcoin && git checkout --detach "$DOGMODE_COMMIT" \
    && test "$(git rev-parse HEAD)" = "$DOGMODE_COMMIT" \
    && echo "building $(git log -1 --format='%H %s')"
WORKDIR /src/bitcoin
# The repository's own dependency builds for this machine's triplet (boost, libevent,
# sqlite, zeromq, static), then the client against them. No GUI, no tests, no benches.
RUN make -C depends -j"$(nproc)" NO_QT=1 NO_QR=1 NO_USDT=1 \
    && TC="$(ls depends/*-linux-gnu/toolchain.cmake | head -1)" && echo "toolchain: $TC" \
    && cmake -B build --toolchain "$TC" -G Ninja \
         -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=OFF -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF \
         -DBUILD_FUZZ_BINARY=OFF -DBUILD_GUI_TESTS=OFF -DCMAKE_INSTALL_PREFIX=/opt/dogmode \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build --strip \
    && mkdir -p /out \
    && for b in bitcoind bitcoin-cli bitcoin bitcoin-tx bitcoin-util bitcoin-wallet; do \
         if [ -x "/opt/dogmode/bin/$b" ]; then cp "/opt/dogmode/bin/$b" /out/; fi; done \
    && if [ -x /opt/dogmode/libexec/bitcoin-node ]; then cp /opt/dogmode/libexec/bitcoin-node /out/; fi \
    && cd /out && sha256sum * | tee SHA256SUMS \
    && ./bitcoind --version | head -1

# The licenses travel with the binaries. Bitcoin Core's COPYING (MIT, "The Bitcoin Core developers") covers the
# client. The static binaries also carry the depends packages built above (boost, libevent, SQLite, ZeroMQ, Cap'n
# Proto), so their own license files are taken out of the exact source archives depends downloaded and checked by
# hash, and SOURCES lists those archives with their SHA-256, so anyone can fetch the identical sources (ZeroMQ's
# MPL-2.0 asks for that). BUILD names the repository and commit. All of it lands in /usr/share/doc/dogmode.
RUN mkdir -p /doc/licenses \
    && cp COPYING /doc/COPYING \
    && ( cd depends/sources && sha256sum * > /doc/SOURCES ) \
    && for a in depends/sources/*.tar.*; do \
         n="$(basename "$a")"; n="${n%%.tar.*}"; mkdir -p "/doc/licenses/$n"; \
         tar -xf "$a" -C "/doc/licenses/$n" --wildcards --no-anchored \
           'LICENSE*' 'LICENCE*' 'COPYING*' 'NOTICE*' 2>/dev/null || true; \
       done \
    && find /doc/licenses -type d -empty -delete \
    && printf 'DOG Mode bitcoind built from %s at commit %s\nPackaged by the Dog of Bitcoin Foundation (contact@dogofbitcoin.org). Not an official DOG Mode release.\n' "$DOGMODE_REPO" "$DOGMODE_COMMIT" > /doc/BUILD \
    && test -s /doc/COPYING && test -s /doc/SOURCES \
    && find /doc -type f | sort

FROM debian:bookworm-slim
ARG DOGMODE_COMMIT
LABEL org.opencontainers.image.title="DOG Mode bitcoind" \
      org.opencontainers.image.source="https://github.com/dogofbitcoin/docker-dogmode" \
      org.opencontainers.image.url="https://github.com/bitcoindogmode/bitcoin" \
      org.opencontainers.image.vendor="Dog of Bitcoin Foundation" \
      org.opencontainers.image.authors="Dog of Bitcoin Foundation <contact@dogofbitcoin.org>" \
      org.opencontainers.image.description="DOG Mode bitcoind (the DOG Mode project, built on Bitcoin Core) compiled from source at bitcoindogmode/bitcoin commit ${DOGMODE_COMMIT} and packaged by the Dog of Bitcoin Foundation. Not an official DOG Mode release. Licenses in /usr/share/doc/dogmode." \
      org.opencontainers.image.revision="${DOGMODE_COMMIT}" \
      org.opencontainers.image.licenses="MIT AND BSD-3-Clause AND BSL-1.0 AND MPL-2.0 AND blessing"
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /out/ /bin/
COPY --from=builder /doc/ /usr/share/doc/dogmode/
RUN mv /bin/SHA256SUMS /SHA256SUMS && cat /SHA256SUMS && ls /usr/share/doc/dogmode
ENV HOME=/data
VOLUME /data/.bitcoin
EXPOSE 8332 8333
ENTRYPOINT ["bitcoind"]
