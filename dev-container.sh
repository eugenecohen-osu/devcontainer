#!/usr/bin/env bash
#
# Build and start a C++ development container using Apple's container CLI
# (https://github.com/apple/container), for use with VS Code.
#
#   - Running container with this name  -> error
#   - Stopped container with this name  -> restarted as-is
#   - No container with this name       -> image built, container created
#
# Mounts:
#   /workspace  host directory (bind mount; convenient, but slower I/O)
#   /data       named volume <name>-data (ext4 block device; fast I/O,
#               use this for large data files and build output)
#   ~/.ssh      host ~/.ssh, read-only (ssh keys for git)
#
# The container gets all host CPUs and 50% of host memory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NAME="dev"
WORKSPACE="$PWD"

usage() {
    cat <<EOF
Usage: $(basename "$0") [-n NAME] [-w DIR]

  -n NAME   Container name (default: dev)
  -w DIR    Host directory to mount at /workspace (default: current directory)
  -h        Show this help
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

while getopts ":n:w:h" opt; do
    case "$opt" in
        n) NAME="$OPTARG" ;;
        w) WORKSPACE="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) usage >&2; die "option -$OPTARG requires an argument" ;;
        *) usage >&2; die "unknown option -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || { usage >&2; die "unexpected argument: $1"; }

command -v container >/dev/null || die "'container' CLI not found; install it from https://github.com/apple/container"
command -v jq >/dev/null || die "'jq' not found"
[[ -d "$WORKSPACE" ]] || die "workspace directory does not exist: $WORKSPACE"
WORKSPACE="$(cd "$WORKSPACE" && pwd)"

IMAGE="local/${NAME}:latest"
VOLUME="${NAME}-data"

# Make sure the container system service is running.
if ! container system status >/dev/null 2>&1; then
    echo "Starting container system service..."
    container system start --enable-kernel-install
fi

state="$(container list --all --format json \
    | jq -r --arg name "$NAME" '.[] | select(.id == $name) | .status.state')"

case "$state" in
    running)
        die "container '$NAME' is already running"
        ;;
    "")
        ;;
    *)
        echo "Restarting existing container '$NAME' (state: $state)..."
        container start "$NAME" >/dev/null
        echo "Container '$NAME' started."
        exit 0
        ;;
esac

echo "Building image '$IMAGE'..."
container build \
    --tag "$IMAGE" \
    --build-arg "USERNAME=$(id -un)" \
    --build-arg "USER_UID=$(id -u)" \
    --build-arg "USER_GID=$(id -g)" \
    --file "$SCRIPT_DIR/Dockerfile" \
    "$SCRIPT_DIR"

if ! container volume inspect "$VOLUME" >/dev/null 2>&1; then
    echo "Creating volume '$VOLUME'..."
    container volume create "$VOLUME" >/dev/null
fi

# Share the host's ssh keys/config (read-only) for git over ssh.
ssh_mount=()
if [[ -d "$HOME/.ssh" ]]; then
    ssh_mount=(--mount "type=bind,source=$HOME/.ssh,target=/home/$(id -un)/.ssh,readonly")
fi

host_cpus="$(sysctl -n hw.ncpu)"
# Leave half of host memory for macOS. Linux fills spare guest RAM with
# page cache, which macOS sees as VM memory it can't reclaim, so a large
# file copy can otherwise push the host out of memory.
mem_mib="$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 2 ))"

echo "Starting container '$NAME' (${host_cpus} CPUs, ${mem_mib} MiB)..."
container run \
    --detach \
    --init \
    --name "$NAME" \
    --cpus "$host_cpus" \
    --memory "${mem_mib}M" \
    --volume "$WORKSPACE:/workspace" \
    --volume "$VOLUME:/data" \
    ${ssh_mount[@]+"${ssh_mount[@]}"} \
    "$IMAGE" >/dev/null

# A fresh volume's root directory is owned by root; hand it to the dev user.
container exec --user root "$NAME" chown "$(id -u):$(id -g)" /data

echo "Container '$NAME' started."
echo "  /workspace -> $WORKSPACE"
echo "  /data      -> volume '$VOLUME'"
[[ ${#ssh_mount[@]} -eq 0 ]] || echo "  ~/.ssh     -> $HOME/.ssh (read-only)"
