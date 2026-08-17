#!/usr/bin/env bash
set -eux -o pipefail

# pre-install (docker)
groupadd -g 913 docker

# pre-install (1password): https://github.com/bsherman/ublue-custom/blob/main/build_files/1password.sh
groupadd -g 1790 onepassword
groupadd -g 1791 onepassword-cli
groupadd -g 1792 onepassword-mcp
