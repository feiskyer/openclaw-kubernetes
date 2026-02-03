#!/usr/bin/env bash
set -euo pipefail

chart_dir="${CHART_DIR:-.}"
release_name="${RELEASE_NAME:-openclaw}"
values_files=(
  "values.yaml"
  "values-development.yaml"
  "values-production.yaml"
  "values-minimal.yaml"
)

for values_file in "${values_files[@]}"; do
  if [ -f "${chart_dir}/${values_file}" ]; then
    echo "==> helm template ${release_name} ${chart_dir} -f ${values_file}"
    helm template "${release_name}" "${chart_dir}" -f "${chart_dir}/${values_file}" --set secrets.openclawGatewayToken=lint-token > /dev/null
  fi
done
