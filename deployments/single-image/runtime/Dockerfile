ARG NODE_IMAGE=node:22-bookworm-slim
ARG GOLANG_IMAGE=golang:1.25-trixie
ARG NGINX_IMAGE=nginx:1.29-trixie

FROM ${NODE_IMAGE} AS web-build
WORKDIR /src/web
COPY web/package.json web/pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY web ./
RUN pnpm build

FROM ${GOLANG_IMAGE} AS service-build
WORKDIR /src
ARG LADYBUG_VERSION=0.13.1
ARG LADYBUG_OS=linux
ARG LADYBUG_ARCH=auto
ARG LADYBUG_DOWNLOAD_URL=
ARG TARGETARCH
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    ladybug_arch="${LADYBUG_ARCH}"; \
    if [ "${ladybug_arch}" = "auto" ]; then \
      case "${TARGETARCH}" in \
        amd64) ladybug_arch="x86_64" ;; \
        arm64) ladybug_arch="aarch64" ;; \
        *) echo "unsupported Docker TARGETARCH=${TARGETARCH}; set LADYBUG_ARCH explicitly" >&2; exit 1 ;; \
      esac; \
    fi; \
    if [ -z "${LADYBUG_DOWNLOAD_URL}" ]; then \
      LADYBUG_DOWNLOAD_URL="https://github.com/LadybugDB/ladybug/releases/download/v${LADYBUG_VERSION}/liblbug-${LADYBUG_OS}-${ladybug_arch}.tar.gz"; \
    fi; \
    mkdir -p /opt/ladybug; \
    curl -fsSL "${LADYBUG_DOWNLOAD_URL}" -o /tmp/liblbug.tar.gz; \
    tar -xzf /tmp/liblbug.tar.gz -C /opt/ladybug; \
    rm -f /tmp/liblbug.tar.gz; \
    find /opt/ladybug -maxdepth 4 -type f | sort
COPY go.mod go.sum ./
RUN go mod download
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) go_ladybug_platform="linux-amd64" ;; \
      arm64) go_ladybug_platform="linux-arm64" ;; \
      *) echo "unsupported Docker TARGETARCH=${TARGETARCH}; set LADYBUG_ARCH explicitly" >&2; exit 1 ;; \
    esac; \
    go_ladybug_dir="$(go env GOMODCACHE)/github.com/!ladybug!d!b/go-ladybug@v${LADYBUG_VERSION}"; \
    go_ladybug_lib_dir="${go_ladybug_dir}/lib/dynamic/${go_ladybug_platform}"; \
    mkdir -p "${go_ladybug_lib_dir}"; \
    liblbug="$(find /opt/ladybug -name 'liblbug.so*' -type f | head -n 1)"; \
    if [ -z "${liblbug}" ]; then \
      echo "liblbug.so was not found under /opt/ladybug" >&2; \
      find /opt/ladybug -maxdepth 4 -type f >&2; \
      exit 1; \
    fi; \
    cp "${liblbug}" "${go_ladybug_lib_dir}/liblbug.so"; \
    if [ -f /opt/ladybug/lbug.h ]; then cp /opt/ladybug/lbug.h "${go_ladybug_dir}/lbug.h"; fi; \
    mkdir -p /opt/ladybug/runtime; \
    cp "${liblbug}" /opt/ladybug/runtime/liblbug.so
COPY cmd ./cmd
COPY internal ./internal
COPY pkg ./pkg
RUN CGO_ENABLED=1 \
    CGO_CFLAGS="-I/opt/ladybug" \
    CGO_LDFLAGS="-Wl,-rpath,/usr/local/lib" \
    go build -tags "ladybug system_ladybug" -o /out/umodel-server-mcp ./cmd/umodel-server-mcp \
    && go build -tags "ladybug system_ladybug" -o /out/umodel-mcp ./cmd/umodel-mcp

FROM ${NGINX_IMAGE}
RUN apt-get update \
    && apt-get install -y --no-install-recommends libstdc++6 libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=service-build /out/umodel-server-mcp /usr/local/bin/umodel-server-mcp
COPY --from=service-build /out/umodel-mcp /usr/local/bin/umodel-mcp
COPY --from=service-build /opt/ladybug/runtime/ /usr/local/lib/
COPY --from=web-build /src/web/dist /usr/share/nginx/html
COPY deployments/single-image/runtime/nginx.conf /etc/nginx/conf.d/default.conf
COPY deployments/single-image/runtime/entrypoint.sh /usr/local/bin/umodel-entrypoint
RUN chmod +x /usr/local/bin/umodel-entrypoint
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV UMODEL_API_ADDR=:8080 \
    UMODEL_DATA=/data \
    UMODEL_GRAPHSTORE=local.ladybug \
    UMODEL_MCP_ENABLED=1 \
    UMODEL_MCP_ADDR=:8090 \
    UMODEL_MCP_WORKSPACE=demo
VOLUME ["/data"]
EXPOSE 8080 5173 8090
ENTRYPOINT ["/usr/local/bin/umodel-entrypoint"]
