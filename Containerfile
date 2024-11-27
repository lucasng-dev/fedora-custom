ARG IMAGE_SOURCE=quay.io/fedora/fedora-silverblue
ARG IMAGE_TAG=41

FROM scratch AS sources
COPY / /

FROM ${IMAGE_SOURCE}:${IMAGE_TAG}
RUN --mount=type=bind,from=sources,src=/,dst=/sources \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    cp -r /sources/rootfs/* / && \
    /sources/build.sh && \
    ostree container commit
