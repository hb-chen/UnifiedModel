#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

DOCKER_BIN="${DOCKER_BIN:-docker}"
DOCKER_HELPER_PATH="${DOCKER_HELPER_PATH:-/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/opt/homebrew/bin}"
IMAGE="${UMODEL_IMAGE:-umodel-ladybug:local}"
LADYBUG_VERSION="${LADYBUG_VERSION:-0.13.1}"
LADYBUG_OS="${LADYBUG_OS:-linux}"
LADYBUG_ARCH="${LADYBUG_ARCH:-x86_64}"
LADYBUG_DOWNLOAD_URL="${LADYBUG_DOWNLOAD_URL:-}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
NODE_IMAGE="${NODE_IMAGE:-node:22-bookworm-slim}"
GOLANG_IMAGE="${GOLANG_IMAGE:-golang:1.25-trixie}"
NGINX_IMAGE="${NGINX_IMAGE:-nginx:1.29-trixie}"
HTTP_PROXY="${HTTP_PROXY:-${http_proxy:-}}"
HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-}}"
NO_PROXY="${NO_PROXY:-${no_proxy:-}}"
DOCKER_HOST_GATEWAY="${DOCKER_HOST_GATEWAY:-host-gateway}"

export PATH="${DOCKER_HELPER_PATH}:${PATH}"

rewrite_loopback_proxy() {
  local proxy="$1"
  if [[ -z "${proxy}" ]]; then
    return
  fi

  proxy="${proxy/127.0.0.1/host.docker.internal}"
  proxy="${proxy/localhost/host.docker.internal}"
  proxy="${proxy/\[::1\]/host.docker.internal}"
  printf '%s\n' "${proxy}"
}

BUILD_HTTP_PROXY="$(rewrite_loopback_proxy "${HTTP_PROXY}")"
BUILD_HTTPS_PROXY="$(rewrite_loopback_proxy "${HTTPS_PROXY}")"
BUILD_NO_PROXY="${NO_PROXY}"
if [[ "${BUILD_HTTP_PROXY}" != "${HTTP_PROXY}" || "${BUILD_HTTPS_PROXY}" != "${HTTPS_PROXY}" ]]; then
  build_uses_host_proxy=1
  if [[ -n "${BUILD_NO_PROXY}" ]]; then
    BUILD_NO_PROXY="${BUILD_NO_PROXY},host.docker.internal"
  else
    BUILD_NO_PROXY="host.docker.internal"
  fi
else
  build_uses_host_proxy=0
fi

build_args=(
  -f "${PRACTICE_DIR}/runtime/Dockerfile"
  --platform "${DOCKER_PLATFORM}"
  --build-arg "LADYBUG_VERSION=${LADYBUG_VERSION}"
  --build-arg "LADYBUG_OS=${LADYBUG_OS}"
  --build-arg "LADYBUG_ARCH=${LADYBUG_ARCH}"
  --build-arg "LADYBUG_DOWNLOAD_URL=${LADYBUG_DOWNLOAD_URL}"
  --build-arg "NODE_IMAGE=${NODE_IMAGE}"
  --build-arg "GOLANG_IMAGE=${GOLANG_IMAGE}"
  --build-arg "NGINX_IMAGE=${NGINX_IMAGE}"
)

if [[ "${build_uses_host_proxy}" == "1" ]]; then
  build_args+=(--add-host "host.docker.internal:${DOCKER_HOST_GATEWAY}")
fi

if [[ -n "${BUILD_HTTP_PROXY}" ]]; then
  build_args+=(--build-arg "HTTP_PROXY=${BUILD_HTTP_PROXY}" --build-arg "http_proxy=${BUILD_HTTP_PROXY}")
fi
if [[ -n "${BUILD_HTTPS_PROXY}" ]]; then
  build_args+=(--build-arg "HTTPS_PROXY=${BUILD_HTTPS_PROXY}" --build-arg "https_proxy=${BUILD_HTTPS_PROXY}")
fi
if [[ -n "${BUILD_NO_PROXY}" ]]; then
  build_args+=(--build-arg "NO_PROXY=${BUILD_NO_PROXY}" --build-arg "no_proxy=${BUILD_NO_PROXY}")
fi

cd "${ROOT_DIR}"
docker_args=(build "${build_args[@]}" -t "${IMAGE}" .)
"${DOCKER_BIN}" "${docker_args[@]}"
