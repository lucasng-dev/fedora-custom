#!/bin/bash
set -eux -o pipefail

podman build -t fedora-custom -f Containerfile .
podman run --rm -it -u root fedora-custom /bin/bash
