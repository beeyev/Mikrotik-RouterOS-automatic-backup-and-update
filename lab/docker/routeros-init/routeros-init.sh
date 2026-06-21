#!/bin/sh
set -eu

deadline="$(($(date +%s) + 120))"

while [ "$(date +%s)" -lt "$deadline" ]; do
  if ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    -o PreferredAuthentications=none \
    -o LogLevel=ERROR \
    admin@routeros \
    "/tool e-mail set server=mailpit port=1025 from=routeros@example.test tls=no"; then
    echo "RouterOS e-mail settings applied."
    exit 0
  fi

  sleep 2
done

echo "Timed out waiting for RouterOS SSH." >&2
exit 1
