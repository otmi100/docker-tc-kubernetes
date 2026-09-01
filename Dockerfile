FROM golang:alpine AS hapttic

RUN apk upgrade --update --no-cache && \
    apk add git && \
    git clone https://github.com/jsoendermann/hapttic.git && \
    cd hapttic/ && \
    go mod init github.com/jsoendermann/hapttic && \
    go build -o hapttic .

FROM alpine:3.20

COPY --from=hapttic /go/hapttic/hapttic /usr/bin/hapttic
# kmod: the init container's modprobe. busybox' applet cannot read the
# zstd-compressed modules that current distros ship.
RUN apk add --no-cache bash iproute2 util-linux kmod curl jq && \
    chmod +x /usr/bin/hapttic

ADD bin /docker-tc/bin

EXPOSE 4080/tcp
ARG VERSION=dev
ENV DOCKER_TC_VERSION="${VERSION:-dev}" \
    HTTP_BIND=127.0.0.1 \
    HTTP_PORT=4080

ENTRYPOINT ["/bin/bash", "/docker-tc/bin/entrypoint.sh"]
