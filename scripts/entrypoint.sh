#!/usr/bin/env sh

set -eu

CONFIG_DIR="/etc/amnezia/amneziawg"

INTERFACES=""

cleanup() {
  for iface in $INTERFACES; do
    echo "[entrypoint] Bringing down interface: $iface"
    awg-quick down "$iface" 2>/dev/null || true
  done
}

trap cleanup EXIT
trap 'exit 0' INT TERM

if ! ls "$CONFIG_DIR"/*.conf >/dev/null 2>&1; then
  echo "[entrypoint] No .conf files found in $CONFIG_DIR"
  exit 1
fi

for conf in "$CONFIG_DIR"/*.conf; do
  iface=$(basename "$conf" .conf)
  echo "[entrypoint] Bringing up interface: $iface"
  awg-quick up "$iface"
  INTERFACES="$INTERFACES $iface"
done

sleep infinity &
wait
