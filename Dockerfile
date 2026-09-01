FROM golang:alpine AS hapttic

RUN apk upgrade --update --no-cache && \
    apk add git && \
    git clone https://github.com/jsoendermann/hapttic.git && \
    cd hapttic/ && \
    go mod init github.com/jsoendermann/hapttic && \
    go build -o hapttic .

FROM alpine:3.20

COPY --from=hapttic /go/hapttic/hapttic /usr/bin/hapttic
RUN apk add --no-cache bash iproute2 util-linux curl jq && \
    chmod +x /usr/bin/hapttic

ADD bin /docker-tc/bin

EXPOSE 4080/tcp
ARG VERSION=dev
ENV DOCKER_TC_VERSION="${VERSION:-dev}" \
    HTTP_BIND=127.0.0.1 \
    HTTP_PORT=4080

# Shell form intentionally: HTTP_BIND/HTTP_PORT must expand at runtime.
ENTRYPOINT hapttic -file /docker-tc/bin/httpd.sh -logErrors -host "$HTTP_BIND" -port "$HTTP_PORT"
