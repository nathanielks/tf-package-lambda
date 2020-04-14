#!/usr/bin/env bash

set -e

if ! command -v jq >/dev/null 2>&1; then
  >&2 echo "jq is not installed, cannot package javascript project. Please install jq to proceed."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  >&2 echo "npm is not installed, cannot package javascript project. Please install npm to proceed."
  exit 1
fi

if ! command -v deterministic-zip >/dev/null 2>&1; then
  >&2 echo "deterministic-zip is not installed, cannot package javascript project. Please install deterministic-zip to proceed: https://github.com/orf/deterministic-zip"
  exit 1
fi

eval "$(jq -r '@sh "SOURCE_DIR=\(.source_dir) BUILD_DIR=\(.build_dir) OUTPUT_PATH=\(.output_path)"')"

SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"
OUTPUT_PATH="${OUTPUT_PATH/#\~/$HOME}"

mkdir -p "${BUILD_DIR}" "$(dirname $OUTPUT_PATH)"

rsync -a --delete --exclude 'node_modules' "${SOURCE_DIR}/" "${BUILD_DIR}/" > /dev/null

NPM_PROGRESS="$(npm get progress)"

cd "${BUILD_DIR}"

npm ci --loglevel=error > /dev/null

chmod -R 0755 .
[[ -d node_modules/.bin ]] && chmod -R 0777 node_modules/.bin

# find * -print0 | \
  # xargs -0 touch -a -m -t 203801181205.09

# npm adds the absolute file path to the installed npm modules' package.json.
# This will remove those paths in order to make builds deterministic. See this
# package for more info:
# https://www.npmjs.com/package/removeNPMAbsolutePaths
# https://github.com/npm/npm/issues/10393

npx removeNPMAbsolutePaths "${BUILD_DIR}" >/dev/null 2>&1

deterministic-zip $OUTPUT_PATH "${BUILD_DIR}" >/dev/null 2>&1

jq -n \
  --arg build_dir "$BUILD_DIR" \
  --arg output_path "$OUTPUT_PATH" \
  '{"packaged_dir":$build_dir, "output_path":$output_path}'
