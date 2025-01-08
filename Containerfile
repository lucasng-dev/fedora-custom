ARG BASE_IMAGE=quay.io/fedora/fedora-silverblue:41

FROM scratch AS sources
COPY rootfs /rootfs
COPY build.sh /

FROM ${BASE_IMAGE}
RUN --mount=type=bind,from=sources,src=/,dst=/sources \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/var \
    cd "$(mktemp -d)" && systemd-tmpfiles --create --prefix=/var --prefix=/usr/local && \
    cp -a /sources/rootfs/. / && /sources/build.sh && \
    mv /var/{opt,usrlocal} /usr/lib/ && find /usr/lib/opt/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | xargs -I'{}' \
    echo 'L /var/opt/{} - - - - /usr/lib/opt/{}' > /usr/lib/tmpfiles.d/zz-opt.conf && \
    ostree container commit
