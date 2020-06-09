#!/usr/bin/env bash
set -Eeuo pipefail

# Add binaries shipped with module to path
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p "$BIN_DIR/lib" /tmp/lib
export PATH="$BIN_DIR/binaries/linux:$PATH"

semaphore=/tmp/decompress-node-v12.18.0-linux-x64
if ! [[ -d /tmp/lib/node-v12.18.0-linux-x64 ]]; then
  touch $semaphore
  tar -xf "$BIN_DIR/archives/node-v12.18.0-linux-x64.tar.xz" -C "/tmp/lib"
  rm $semaphore
fi

# if ! command -v npm >/dev/null 2>&1; then
# check if the symlink exists and otherwise install it. We check the presence
# of the symlink instead of the command so other modules don't decompress

# If the sempaphore exists, wait till it's complete
while [[ -f $semaphore ]]
do
     sleep 1
done
ln -sf "/tmp/lib/node-v12.18.0-linux-x64/bin/npm" "$BIN_DIR/binaries/linux/npm"
ln -sf "/tmp/lib/node-v12.18.0-linux-x64/bin/node" "$BIN_DIR/binaries/linux/node"
ln -sf "/tmp/lib/node-v12.18.0-linux-x64/bin/npx" "$BIN_DIR/binaries/linux/npx"

# if ! command -v jq >/dev/null 2>&1; then
# if ! [[ -L /tmp/bin/jq ]]; then
  # ln -sf "$BIN_DIR/binaries/linux/jq" /tmp/bin/jq
# fi

# if ! command -v deterministic-zip >/dev/null 2>&1; then
# if ! [[ -L /tmp/bin/deterministic-zip ]]; then
  # ln -sf "$BIN_DIR/binaries/linux/deterministic-zip" /tmp/bin/deterministic-zip
# fi
chmod +x $BIN_DIR/binaries/linux/*


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
