FROM rust:1-slim-bookworm AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends pkg-config libssl-dev curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY reference-code/domain-manager-service/ .

ENV SQLX_OFFLINE=true
RUN cargo build --release --bin domain-manager-service

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/domain-manager-service /usr/local/bin/domain-manager-service

ENV RUST_LOG=info
EXPOSE 8080 18190

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl --fail http://127.0.0.1:8080/health || exit 1

CMD ["domain-manager-service"]
