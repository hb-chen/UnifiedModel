#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

CONTAINER="${UMODEL_CONTAINER:-umodel}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DOCKER_HELPER_PATH="${DOCKER_HELPER_PATH:-/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/opt/homebrew/bin}"

export PATH="${DOCKER_HELPER_PATH}:${PATH}"

"${DOCKER_BIN}" stop "${CONTAINER}"
"${DOCKER_BIN}" rm "${CONTAINER}"
