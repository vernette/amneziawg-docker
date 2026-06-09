# amneziawg-go (userspace)
FROM golang:1.26-alpine AS build-go

ARG AWG_GO_REF=master

WORKDIR /src

RUN apk add --no-cache git make

RUN git clone --depth 1 --branch "${AWG_GO_REF}" https://github.com/amnezia-vpn/amneziawg-go.git . && \
  make

# amneziawg-tools (awg + awg-quick)
FROM alpine:3.22 AS build-tools

ARG AWG_TOOLS_REF=master

WORKDIR /src

RUN apk add --no-cache git build-base linux-headers bash

RUN git clone --depth 1 --branch "${AWG_TOOLS_REF}" https://github.com/amnezia-vpn/amneziawg-tools.git . && \
  make -C src && \
  make -C src install DESTDIR=/out WITH_WGQUICK=yes

# runtime
FROM alpine:3.22

RUN apk add --no-cache iproute2 iptables ip6tables openresolv bash

COPY --from=build-go /src/amneziawg-go /usr/bin/amneziawg-go
COPY --from=build-tools /out/usr/bin/awg /usr/bin/awg
COPY --from=build-tools /out/usr/bin/awg-quick /usr/bin/awg-quick

RUN mkdir -p /etc/amnezia/amneziawg

ENV WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go \
  WG_I_PREFER_BUGGY_USERSPACE_TO_POLISHED_KMOD=1

COPY --chmod=755 entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
