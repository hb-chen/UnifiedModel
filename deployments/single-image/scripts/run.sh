#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

IMAGE="${UMODEL_IMAGE:-umodel-ladybug:local}"
CONTAINER="${UMODEL_CONTAINER:-umodel}"
HOST_DATA="${UMODEL_HOST_DATA:-${ROOT_DIR}/.run/umodel-ladybug/data}"
WEB_PORT="${UMODEL_WEB_PORT:-5173}"
API_PORT="${UMODEL_API_PORT:-8080}"
MCP_PORT="${UMODEL_MCP_PORT:-8090}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DOCKER_HELPER_PATH="${DOCKER_HELPER_PATH:-/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/opt/homebrew/bin}"

HOST_DATA="$(resolve_repo_path "${HOST_DATA}")"

export PATH="${DOCKER_HELPER_PATH}:${PATH}"

mkdir -p "${HOST_DATA}"

"${DOCKER_BIN}" run -d \
  --name "${CONTAINER}" \
  --restart unless-stopped \
  -p "${WEB_PORT}:5173" \
  -p "${API_PORT}:8080" \
  -p "${MCP_PORT}:8090" \
  -v "${HOST_DATA}:/data" \
  -e UMODEL_GRAPHSTORE=local.ladybug \
  -e UMODEL_MCP_ADDR=:8090 \
  "${IMAGE}"

echo "UModel Web: http://localhost:${WEB_PORT}"
echo "UModel API: http://localhost:${API_PORT}"
echo "UModel MCP: http://localhost:${MCP_PORT}/mcp"
