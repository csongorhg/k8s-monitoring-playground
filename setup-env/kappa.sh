#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

replace=false
force=false

while getopts ':rf' opt; do
  case "$opt" in
  r) replace=true ;;
  f) force=true ;;
  *) exit 1 ;;
  esac
done

shift $((OPTIND - 1))

prefix="${1:-}"

if [[ -n "$prefix" ]]; then
  files=("${prefix}"*.yaml)
else
  files=(*.yaml)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo 'No matching yaml files found.'
  exit 0
fi

if [[ "$replace" == true && "$force" == true ]]; then
  echo 'Files to replace forcefully:'
elif [[ "$replace" == true ]]; then
  echo 'Files to replace:'
elif [[ "$force" == true ]]; then
  echo 'Files to apply forcefully:'
else
  echo 'Files to apply:'
fi

for file in "${files[@]}"; do
  echo "  $file"
done

read -r -p 'Continue? [y/N] ' answer
case "${answer:-}" in
y | Y | yes | YES) ;;
*)
  echo 'Aborted.'
  exit 1
  ;;
esac

for file in "${files[@]}"; do
  if [[ "$replace" == true && "$force" == true ]]; then
    kubectl replace --force -f "$file"
  elif [[ "$replace" == true ]]; then
    kubectl replace -f "$file"
  elif [[ "$force" == true ]]; then
    kubectl apply --force -f "$file"
  else
    kubectl apply -f "$file"
  fi
done
