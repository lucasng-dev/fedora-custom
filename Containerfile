ARG UPSTREAM_IMAGE=quay.io/fedora-ostree-desktops/silverblue:43

FROM ${UPSTREAM_IMAGE}

COPY rootfs /tmp/sources/rootfs
COPY scripts/build.sh /tmp/sources/scripts/

RUN set -eux -o pipefail && cd /tmp/sources && \
    systemd-tmpfiles --create --prefix=/var --prefix=/usr/local && \
    mv /var/usrlocal /usr/lib/ && ln -srT /usr/lib/usrlocal /var/usrlocal && \
    rm -f /opt && mv /var/opt / && \
    cp -a rootfs/. / && /bin/bash scripts/build.sh && \
    dnf autoremove -y && dnf clean all -y && find /etc/ -type f -name '*.rpmnew' -delete && \
    find /var/ /tmp/ -mindepth 1 -maxdepth 1 -exec rm -rf '{}' \; && \
    ostree container commit && bootc container lint
