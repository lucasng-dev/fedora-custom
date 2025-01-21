# Fedora Silverblue (custom build)

[![Build Fedora](https://github.com/lucasng-dev/fedora-custom/actions/workflows/build.yml/badge.svg)](https://github.com/lucasng-dev/fedora-custom/actions/workflows/build.yml)

Custom Fedora Silverblue [OCI image](https://coreos.github.io/rpm-ostree/container/).

Based on Fedora Silverblue [upstream image](https://quay.io/repository/fedora/fedora-silverblue) and scripts from [ublue-os/main](https://github.com/ublue-os/main).

## Usage

```sh
rpm-ostree rebase ostree-unverified-registry:ghcr.io/lucasng-dev/fedora-custom:latest
```
