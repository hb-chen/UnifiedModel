#!/bin/sh
set -eu

api_addr="${UMODEL_API_ADDR:-:8080}"
data_root="${UMODEL_DATA:-/data}"
graphstore="${UMODEL_GRAPHSTORE:-local.ladybug}"

mkdir -p "${data_root}"

umodel-server-mcp --addr "${api_addr}" --data "${data_root}" --graphstore "${graphstore}" &
api_pid="$!"

nginx -g "daemon off;" &
nginx_pid="$!"

wait_process() {
  set +e
  wait "$1"
  process_status="$?"
  set -e
}

shutdown() {
  kill -TERM "${api_pid}" "${nginx_pid}" 2>/dev/null || true
  wait "${api_pid}" 2>/dev/null || true
  wait "${nginx_pid}" 2>/dev/null || true
}

trap shutdown INT TERM

while true; do
  if ! kill -0 "${api_pid}" 2>/dev/null; then
    wait_process "${api_pid}"
    exit "${process_status}"
  fi
  if ! kill -0 "${nginx_pid}" 2>/dev/null; then
    wait_process "${nginx_pid}"
    status="${process_status}"
    kill -TERM "${api_pid}" 2>/dev/null || true
    wait "${api_pid}" 2>/dev/null || true
    exit "${status}"
  fi
  sleep 1
done
