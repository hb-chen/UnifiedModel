#!/usr/bin/env bash

PRACTICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "${PRACTICE_DIR}/../.." && pwd)"
ENV_FILE="${UMODEL_ENV_FILE:-${PRACTICE_DIR}/.env}"

load_env_file() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    return
  fi

  local line key
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    if [[ "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)= ]]; then
      key="${BASH_REMATCH[1]}"
      if [[ -z "${!key+x}" ]]; then
        eval "export ${line}"
      fi
    fi
  done < "${ENV_FILE}"
}

load_env_file

resolve_repo_path() {
  local path="$1"
  if [[ -z "${path}" || "${path}" = /* ]]; then
    printf '%s\n' "${path}"
    return
  fi
  printf '%s\n' "${ROOT_DIR}/${path}"
}
