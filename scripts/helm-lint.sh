#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
chart_dir="${CHART_DIR:-$(cd "$script_dir/.." && pwd)}"
values_files=(
  "values.yaml"
  "values-development.yaml"
  "values-production.yaml"
  "values-minimal.yaml"
)

for values_file in "${values_files[@]}"; do
  if [ -f "${chart_dir}/${values_file}" ]; then
    echo "==> helm lint ${chart_dir} -f ${values_file}"
    helm lint "${chart_dir}" -f "${chart_dir}/${values_file}" --set secrets.openclawGatewayToken=lint-token
  fi
done
