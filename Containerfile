ARG UPSTREAM_IMAGE=quay.io/fedora-ostree-desktops/silverblue:43

FROM scratch AS sources
COPY . .

FROM ${UPSTREAM_IMAGE}
RUN --mount=type=bind,from=sources,src=/,dst=/sources \
    cd "$(mktemp -d)" && \
    systemd-tmpfiles --create --prefix=/var --prefix=/usr/local && \
    mv /var/usrlocal /usr/lib/ && ln -srT /usr/lib/usrlocal /var/usrlocal && \
    rm -f /opt && mv /var/opt / && \
    cp -a /sources/rootfs/. / && /bin/bash /sources/scripts/build.sh && \
    dnf autoremove -y && dnf clean all -y && find /etc/ -type f -name '*.rpmnew' -delete && \
    find /var/ /tmp/ -mindepth 1 -maxdepth 1 -exec rm -rf '{}' \; && \
    ostree container commit && bootc container lint
