#!/usr/bin/env sh

set -eu

build_all="${1:-no}"
project_dir=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(dirname -- "$0")")
cd "${project_dir}"

export DEPTHS_BUILD_SCRIPT=linux
. "./build.sh"

build Linux x86_64 "${build_all}"
