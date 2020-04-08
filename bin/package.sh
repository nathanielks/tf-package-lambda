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

eval "$(jq -r '@sh "SOURCE_DIR=\(.source_dir) BUILD_DIR=\(.build_dir)"')"

SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"

mkdir -p "${BUILD_DIR}"

rsync -a --delete --exclude 'node_modules' "${SOURCE_DIR}/" "${BUILD_DIR}/" > /dev/null

NPM_PROGRESS="$(npm get progress)"

cd "${BUILD_DIR}"

npm set progress=false \
  && npm install --production --loglevel=error > /dev/null \
  && npm set progress="${NPM_PROGRESS}" \
  && rm -f "${BUILD_DIR}/package-lock.json"

chmod -R 0755 .

find * -print0 | \
  xargs -0 touch -a -m -t 203801181205.09

# npm adds the absolute file path to the installed npm modules' package.json.
# This will remove those paths in order to make builds deterministic. See this
# package for more info:
# https://www.npmjs.com/package/removeNPMAbsolutePaths
# https://github.com/npm/npm/issues/10393

npx removeNPMAbsolutePaths "${BUILD_DIR}"

jq -n --arg build_dir "$BUILD_DIR" '{"packaged_dir":$build_dir}'
