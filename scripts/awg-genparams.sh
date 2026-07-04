#!/usr/bin/env sh

# Generate AmneziaWG 2.0 obfuscation parameters (Jc/Jmin/Jmax, S1-S4, H1-H4, I1).
# Algorithm ported 1:1 from the official Amnezia client.

set -eu

readonly JUNK_PACKET_MIN_SIZE=10
readonly JUNK_PACKET_MAX_SIZE=50

readonly MESSAGE_INITIATION_SIZE=148
readonly MESSAGE_RESPONSE_SIZE=92
readonly MESSAGE_COOKIE_REPLY_SIZE=64

readonly MAGIC_HEADER_MIN=5
readonly MAGIC_HEADER_MAX=2147483647

readonly SPECIAL_JUNK_1='<r 2><b 0x858000010001000000000669636c6f756403636f6d0000010001c00c000100010000105a00044d583737>'

randint() {
  lo=$1
  hi=$2
  span=$((hi - lo))
  if [ "$span" -le 0 ]; then
    printf '%s' "$lo"
    return
  fi
  rand=$(od -An -tu4 -N4 /dev/urandom | tr -d ' ')
  printf '%s' "$((lo + rand % span))"
}

generate_junk_packet_count() {
  randint 4 7
}

generate_packet_junk_sizes() {
  s1=$(randint 15 150)

  s2=$(randint 15 150)
  while [ "$s2" -eq "$s1" ] ||
    [ "$((s1 + MESSAGE_INITIATION_SIZE))" -eq "$((s2 + MESSAGE_RESPONSE_SIZE))" ]; do
    s2=$(randint 15 150)
  done

  s3=$(randint 0 64)
  while [ "$s3" -eq "$s1" ] || [ "$s3" -eq "$s2" ] ||
    [ "$((s1 + MESSAGE_INITIATION_SIZE))" -eq "$((s3 + MESSAGE_COOKIE_REPLY_SIZE))" ] ||
    [ "$((s2 + MESSAGE_RESPONSE_SIZE))" -eq "$((s3 + MESSAGE_COOKIE_REPLY_SIZE))" ]; do
    s3=$(randint 0 64)
  done

  s4=$(randint 0 20)
  while [ "$s4" -eq "$s1" ] || [ "$s4" -eq "$s2" ] || [ "$s4" -eq "$s3" ]; do
    s4=$(randint 0 20)
  done

  printf '%s %s %s %s' "$s1" "$s2" "$s3" "$s4"
}

generate_magic_headers() {
  min=$MAGIC_HEADER_MIN
  i=0
  while [ "$i" -lt 4 ]; do
    first=$(randint "$min" "$MAGIC_HEADER_MAX")
    second=$(randint "$first" "$MAGIC_HEADER_MAX")
    min=$second
    printf '%s-%s\n' "$first" "$second"
    i=$((i + 1))
  done
}

print_shared_block() {
  cat <<EOF
S1 = $s1
S2 = $s2
S3 = $s3
S4 = $s4
H1 = $h1
H2 = $h2
H3 = $h3
H4 = $h4
EOF
}

main() {
  jc=$(generate_junk_packet_count)

  set -- $(generate_packet_junk_sizes)
  s1=$1
  s2=$2
  s3=$3
  s4=$4

  set -- $(generate_magic_headers)
  h1=$1
  h2=$2
  h3=$3
  h4=$4

  cat <<EOF
# ---- Server [Interface] ----
$(print_shared_block)

# ---- Client [Interface] ----
Jc = $jc
Jmin = $JUNK_PACKET_MIN_SIZE
Jmax = $JUNK_PACKET_MAX_SIZE
$(print_shared_block)
I1 = $SPECIAL_JUNK_1
EOF
}

main "$@"
