# Fedora Silverblue (custom build)

[![Build Fedora](https://github.com/lucasng-dev/fedora-custom/actions/workflows/build.yml/badge.svg)](https://github.com/lucasng-dev/fedora-custom/actions/workflows/build.yml)

Custom Fedora Silverblue OCI image based on Fedora Silverblue [upstream image](https://quay.io/repository/fedora/fedora-silverblue).

Based on scripts from [ublue-os/main](https://github.com/ublue-os/main).

## Usage

```sh
rpm-ostree rebase ostree-unverified-image:registry:ghcr.io/lucasng-dev/fedora-custom:latest
```
