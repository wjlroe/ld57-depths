#!/usr/bin/env sh

set -eu

build_all="${1:-no}"
project_dir=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(dirname -- "$0")")
cd "${project_dir}"

export BASE_CODE_BUILD_SCRIPT=rpi
. "./build.sh"

build Linux armv7l "${build_all}"
build Linux aarch64 "${build_all}"
