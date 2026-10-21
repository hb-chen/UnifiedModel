#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

WEB_PORT="${UMODEL_WEB_PORT:-5173}"
API_PORT="${UMODEL_API_PORT:-8080}"
MCP_PORT="${UMODEL_MCP_PORT:-8090}"

curl -fsS "http://localhost:${API_PORT}/healthz"
printf "\n"
curl -fsS "http://localhost:${WEB_PORT}/healthz"
printf "\n"
curl -fsS "http://localhost:${MCP_PORT}/healthz"
printf "\n"
