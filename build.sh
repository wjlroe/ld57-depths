#!/usr/bin/env sh

set -eu

build_all=no
run_after_build=no

first_arg="${1:-}"

if [ "${first_arg}" = "all" ]; then
    build_all=yes
elif [ "${first_arg}" = "run" ]; then
    run_after_build=yes
fi

PATH="/opt/odin/2025-04:${PATH}"

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
    run_after_build="${4:-no}"
    odin_os=$(odin_os "${os}")
    odin_arch=$(odin_arch "${arch}")
    target="${odin_os}_${odin_arch}"

    build_dir="build/${odin_os}/${odin_arch}"
    if building_on_target "${target}"; then
        echo Building on target OS and architecture
        build_dir="build"
    fi
    mkdir -p "${build_dir}"

    build_args=""
    binary_name=depths
    binary_file="${build_dir}/${binary_name}_debug"
    echo "Building debug binary ${binary_file} for target ${target}"

    odin build src \
        ${build_args} \
        -out:"${binary_file}" \
        -build-mode:exe \
        -target:"${target}" \
        -debug \
        -show-timings

    # Print out dynamic library dependencies
    (which otool > /dev/null && otool -L "${binary_file}") || true
    (which ldd > /dev/null && ldd "${binary_file}") || true

    if [ "${build_all}" = yes ]; then
        if [ "${odin_os}" = darwin ]; then
            binary_name=depths.app
        fi
        binary_file="${build_dir}/${binary_name}"
        if [ "${odin_os}" = darwin ]; then
            target="darwin_amd64"
            binary_name=depths_amd64
            binary_file="${build_dir}/${binary_name}"
            echo "Building release binary ${binary_file} for target ${target}"
            odin build src \
                -out:"${binary_file}"\
                -build-mode:exe \
                -target:"${target}" \
                -extra-linker-flags="-arch x86_64" \
                -o:speed \
                -disable-assert \
                -show-timings
            target="darwin_arm64"
            binary_name=depths_arm64
            binary_file="${build_dir}/${binary_name}"
            echo "Building release binary ${binary_file} for target ${target}"
            odin build src \
                -out:"${binary_file}"\
                -build-mode:exe \
                -target:"${target}" \
                -extra-linker-flags="-arch arm64" \
                -o:speed \
                -disable-assert \
                -show-timings
            binary_name=depths
            binary_file="${build_dir}/${binary_name}"
            lipo -create -output "${binary_file}" "${build_dir}/depths_arm64" "${build_dir}/depths_amd64"
        else
            echo "Building release binary ${binary_file} for target ${target}"
            odin build src \
                -out:"${binary_file}"\
                -build-mode:exe \
                -target:"${target}" \
                -o:speed \
                -disable-assert \
                -show-timings
        fi

        # Print out dynamic library dependencies
        (which otool > /dev/null && otool -L "${binary_file}") || true
        (which ldd > /dev/null && ldd "${binary_file}") || true
    elif [ "${run_after_build}" = yes ]; then
        ${binary_file}
    fi
}

if [ -z "${DEPTHS_BUILD_SCRIPT:-}" ]; then
    build "$(uname -s)" "$(uname -m)" "${build_all}" "${run_after_build}"
fi
