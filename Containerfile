ARG BASE_IMAGE=quay.io/fedora/fedora-silverblue:41

FROM scratch AS sources
COPY rootfs /rootfs
COPY build.sh /

FROM ${BASE_IMAGE}
RUN --mount=type=bind,from=sources,src=/,dst=/sources \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    cp -a /sources/rootfs/. / && \
    /sources/build.sh && \
    ostree container commit
