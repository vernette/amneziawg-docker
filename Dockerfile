FROM amneziavpn/amneziawg-go:2.0.0

RUN apk add --no-cache \
  openresolv \
  curl && \
  mkdir -p /etc/amnezia/amneziawg

COPY --chmod=755 entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
