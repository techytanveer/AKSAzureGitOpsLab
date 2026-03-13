# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        g++ \
        make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY CMakeLists.txt .
COPY app/ app/

RUN cmake -B build -DCMAKE_BUILD_TYPE=Release \
 && cmake --build build --parallel "$(nproc)"

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM ubuntu:22.04 AS runtime

RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --from=builder /src/build/server .

RUN chown appuser:appuser /app/server

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/app/server"]
