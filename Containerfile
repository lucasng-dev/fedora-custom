FROM scratch AS sources
COPY . .

FROM quay.io/fedora-ostree-desktops/silverblue:44
RUN --mount=type=bind,from=sources,src=/,dst=/sources \
    --mount=type=tmpfs,tmpfs-size=8G,dst=/var \
    --mount=type=tmpfs,tmpfs-size=4G,dst=/tmp \
    --mount=type=tmpfs,tmpfs-size=2G,dst=/run \
    set -eux -o pipefail && cd /sources && \
    systemd-tmpfiles --create --prefix=/var --prefix=/usr/local && \
    mv -v /var/usrlocal /usr/lib/ && ln -vsrT /usr/lib/usrlocal /var/usrlocal && \
    rm -vf /opt && mv -v /var/opt / && \
    cp -va rootfs/. / && /bin/bash scripts/build.sh && \
    dnf autoremove -y && dnf clean all -y && find /etc/ -type f -name '*.rpmnew' -delete && \
    find /var/ /tmp/ /run/ -mindepth 1 -maxdepth 1 -exec rm -rf '{}' ';' && \
    ostree container commit && bootc container lint
