#!/usr/bin/env bash
set -Eeuo pipefail

eval $(jq -rc '@sh "JSON=\(. | @json)"')
SCRIPTNAME="$(basename ${0})"
MD5="$(echo $JSON | md5sum | cut -d ' ' -f 1)"

ARGSFILE="/tmp/$SCRIPTNAME-$MD5-args"
LOGFILE="/tmp/$SCRIPTNAME-$MD5-logs"
# exec > >(tee -ia $LOGFILE)
# exec 2> $LOGFILE
exec 19> $LOGFILE
export BASH_XTRACEFD="19"

set -x
# Record args to file for debugging
echo ${JSON} | tee $ARGSFILE > /dev/null

trap 'catch $? $LINENO' EXIT
catch() {
  if [[ $1 != "0" ]]; then
    echo "A fatal error occurred, showing error logs..."
    echo "Error code '$1' occurred on line $2"
    echo "Args file: $ARGSFILE"
    echo "Log file: $LOGFILE"
    >&2 cat "$LOGFILE"
  fi
}

eval "$(echo $JSON | jq -r '@sh "SOURCE_DIR=\(.source_dir) BUILD_DIR=\(.build_dir) OUTPUT_PATH=\(.output_path)"')"

# Note we execute the build script portion inside of parenthesis to launch it
# all in a subshell to make redirecting stdout and stderr much easier.
export SHELLOPTS
(
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

  SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
  BUILD_DIR="${BUILD_DIR/#\~/$HOME}"
  OUTPUT_PATH="${OUTPUT_PATH/#\~/$HOME}"

  mkdir -p "${BUILD_DIR}" "$(dirname $OUTPUT_PATH)"

  rsync -a --delete --exclude 'node_modules' "${SOURCE_DIR}/" "${BUILD_DIR}/"

  NPM_PROGRESS="$(npm get progress)"

  cd "${BUILD_DIR}"

  npm ci --loglevel=error

  chmod -R 0755 .
  # node_modules/.bin will be populated with symlinks to executables. Because
  # Linux and MacOS (FreeBSD) treat symlinks differently, we have to manually
  # force MacOS to change the symlinks' permissions to 777. Linux has 777 on
  # symlinks by default.
  # https://unix.stackexchange.com/a/87202/199864
  if [[ "$OSTYPE" == "darwin"* ]]; then
    find node_modules -type l | xargs /bin/chmod -h 777
  else
    echo "Not a MacOS system"
  fi

  # find * -print0 | \
    # xargs -0 touch -a -m -t 203801181205.09

  # npm adds the absolute file path to the installed npm modules' package.json.
  # This will remove those paths in order to make builds deterministic. See this
  # package for more info:
  # https://www.npmjs.com/package/removeNPMAbsolutePaths
  # https://github.com/npm/npm/issues/10393

  npx removeNPMAbsolutePaths "${BUILD_DIR}"

  deterministic-zip $OUTPUT_PATH "${BUILD_DIR}"
) >/dev/null 2> $LOGFILE

jq -n \
  --arg build_dir "$BUILD_DIR" \
  --arg output_path "$OUTPUT_PATH" \
  '{"packaged_dir":$build_dir, "output_path":$output_path}'
