#!/usr/bin/env bash
set -E

JSON=$(jq -rc)
SCRIPTNAME="$(basename ${0})"
MD5="$(echo $JSON | md5sum | cut -d ' ' -f 1)"

ARGSFILE="/tmp/$SCRIPTNAME-$MD5-args"
LOGFILE="/tmp/$SCRIPTNAME-$MD5-logs"
exec > >(tee -ia $LOGFILE)
exec 2> >(tee -ia $LOGFILE >& 2)
exec 3> $LOGFILE

export BASH_XTRACEFD="3"

# Record args to file for debugging
echo ${JSON} | tee $ARGSFILE > /dev/null

trap 'catch $? $LINENO' ERR
catch() {
  echo "A fatal error occurred, showing error logs..."
  echo "Error $1 occurred on $2"
  echo "Args file: $ARGSFILE"
  echo "Log file: $LOGFILE"
  >&2 cat "$LOGFILE"
}

function always(){
  echo exited >&3
}

trap always EXIT
set -eu

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

eval "$(echo $JSON | jq -r '@sh "SOURCE_DIR=\(.source_dir) BUILD_DIR=\(.build_dir) OUTPUT_PATH=\(.output_path)"')"

SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
BUILD_DIR="${BUILD_DIR/#\~/$HOME}"
OUTPUT_PATH="${OUTPUT_PATH/#\~/$HOME}"

mkdir -p "${BUILD_DIR}" "$(dirname $OUTPUT_PATH)" >&3 2>&1

rsync -a --delete --exclude 'node_modules' "${SOURCE_DIR}/" "${BUILD_DIR}/" >&3 2>&1

NPM_PROGRESS="$(npm get progress)"

cd "${BUILD_DIR}"

npm ci --loglevel=error >&3 2>&1

chmod -R 0755 . >&3 2>&1
[[ -d node_modules/.bin ]] && chmod -R 0777 node_modules/.bin >&3 2>&1

# find * -print0 | \
  # xargs -0 touch -a -m -t 203801181205.09

# npm adds the absolute file path to the installed npm modules' package.json.
# This will remove those paths in order to make builds deterministic. See this
# package for more info:
# https://www.npmjs.com/package/removeNPMAbsolutePaths
# https://github.com/npm/npm/issues/10393

npx removeNPMAbsolutePaths "${BUILD_DIR}" >&3 2>&1

deterministic-zip $OUTPUT_PATH "${BUILD_DIR}" >&3 2>&1

jq -n \
  --arg build_dir "$BUILD_DIR" \
  --arg output_path "$OUTPUT_PATH" \
  '{"packaged_dir":$build_dir, "output_path":$output_path}'
