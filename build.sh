#!/usr/bin/env sh

set -eu

build_all="${1:-no}"

odin_cmd=/opt/odin/dev-master/odin

project_dir=$(cd -P -- "$(dirname -- "$0")" && printf '%s\n' "$(pwd -P)/$(dirname -- "$0")")
cd "${project_dir}"

odin_os() {
    os=$1

    case "${os}" in
        Linux)
            echo linux
            ;;
        Darwin)
            echo darwin
            ;;
        *)
            >&2 echo "Unknown OS ${os}!"
            exit 1
            ;;
    esac
}

odin_arch() {
    arch=$1

    case "${arch}" in
        x86_64)
            echo amd64
            ;;
        armv7l)
            echo arm32
            ;;
        aarch64)
            echo arm64
            ;;
        arm64)
            echo arm64
            ;;
        *)
            >&2 echo "Unknown arch ${arch}!"
            exit 1
            ;;
    esac
}

building_on_target() {
    target=$1

    odin_os=$(odin_os "$(uname -s)")
    odin_arch=$(odin_arch "$(uname -m)")
    build_platform="${odin_os}_${odin_arch}"

    if [ "${build_platform}" = "${target}" ]; then
        return 0
    else
        return 1
    fi
}

build() {
    os=$1
    arch=$2
    build_all="${3:-no}"
    odin_os=$(odin_os "${os}")
    odin_arch=$(odin_arch "${arch}")
    target="${odin_os}_${odin_arch}"

    build_dir="build/${odin_os}/${odin_arch}"
    if building_on_target "${target}"; then
        echo Building on target OS and architecture
        build_dir="build"
    fi
    mkdir -p "${build_dir}"

    binary_file="${build_dir}/base_code"
    echo "Building debug binary ${binary_file} for target ${target}"

    $odin_cmd build src \
        -out:"${binary_file}"\
        -build-mode:exe \
        -target:"${target}" \
        -debug \
        -o:minimal \
        -show-timings

    # Print out dynamic library dependencies
    (which otool > /dev/null && otool -L "${binary_file}") || true
    (which ldd > /dev/null && ldd "${binary_file}") || true

    if [ "${build_all}" = all ]; then
        binary_name=base_code_release
        if [ "${odin_os}" = darwin ]; then
            binary_name=base_code_release.app
        fi
        binary_file="${build_dir}/${binary_name}"
        echo "Building release binary ${binary_file} for target ${target}"
        $odin_cmd build src \
            -out:"${binary_file}"\
            -build-mode:exe \
            -target:"${target}" \
            -o:speed \
            -disable-assert \
            -show-timings

        # Print out dynamic library dependencies
        (which otool > /dev/null && otool -L "${binary_file}") || true
        (which ldd > /dev/null && ldd "${binary_file}") || true
    fi
}

if [ -z "${BASE_CODE_BUILD_SCRIPT:-}" ]; then
    build "$(uname -s)" "$(uname -m)" "${build_all}"
fi
