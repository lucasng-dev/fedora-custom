# Fedora Silverblue _(custom build)_

[![Build Fedora](https://github.com/lucasng-dev/fedora-custom/actions/workflows/build.yml/badge.svg)](https://github.com/lucasng-dev/fedora-custom/actions/workflows/build.yml)

Custom Fedora Silverblue [bootable image](https://coreos.github.io/rpm-ostree/container/) based on [BlueBuild](https://github.com/blue-build/template).

## Rebase existing installation _(unsigned)_

```sh
rpm-ostree rebase ostree-unverified-registry:ghcr.io/lucasng-dev/fedora-silverblue:latest
```

## Rebase existing installation _(signed)_

```sh
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/lucasng-dev/fedora-silverblue:latest
```

## Build container from local recipe

```sh
bluebuild build recipes/fedora-silverblue.yml
```

## Build ISO from remote image

```sh
bluebuild generate-iso --output-dir isos --iso-name fedora-silverblue.iso image ghcr.io/lucasng-dev/fedora-silverblue:latest
```

## Build ISO from local recipe

```sh
bluebuild generate-iso --output-dir isos --iso-name fedora-silverblue.iso recipe recipes/fedora-silverblue.yml
```
