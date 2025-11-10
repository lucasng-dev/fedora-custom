ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/silverblue:43

FROM scratch AS sources
COPY . .

FROM ${BASE_IMAGE}
RUN --mount=type=bind,from=sources,src=/,dst=/sources \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/var \
    set -eux -o pipefail && \
    cd "$(mktemp -d)" && \
    systemd-tmpfiles --create --prefix=/var --prefix=/usr/local && \
    cp -a /sources/rootfs/. / && \
    /sources/build.sh && \
    dnf autoremove -y && find /etc/ -type f -name '*.rpmnew' -delete && \
    mv /var/{opt,usrlocal} /usr/lib/ && \
    find /usr/lib/opt/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | xargs -I'{}' \
    echo 'L "/var/opt/{}" - - - - /usr/lib/opt/{}' | tee /usr/lib/tmpfiles.d/zz-opt.conf && \
    rm -rf /tmp/* /var/* && \
    ostree container commit && \
    bootc container lint
