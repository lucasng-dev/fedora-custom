#!/bin/bash
set -eux -o pipefail
cd "$(dirname "${BASH_SOURCE:-$0}")/.."

podman build --squash -t fedora-custom -f Containerfile .
podman run --rm -it -u root fedora-custom /bin/bash
