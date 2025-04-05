#!/usr/bin/env sh

set -eu

build_all="${1:-no}"
project_dir=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(dirname -- "$0")")
cd "${project_dir}"

export DEPTHS_BUILD_SCRIPT=mac
. "./build.sh"

echo "${BASE_CODE_MAC_BUILD_ARCH:=x86_64}"
build Darwin "${BASE_CODE_MAC_BUILD_ARCH}" "${build_all}"
