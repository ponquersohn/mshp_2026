#!/usr/bin/env python3
"""Wait for each QEMU HMP command to complete before disconnecting."""
import re
import socket
import sys


def main():
    if len(sys.argv) not in (3, 4) or sys.argv[2] not in ('save', 'restore', 'list'):
        raise ValueError('usage: snapshot.sh save|restore|list [name]')
    path, action = sys.argv[1:3]
    name = sys.argv[3] if len(sys.argv) == 4 else 'clean'
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', name):
        raise ValueError('snapshot name must contain only letters, digits, _, . or -')
    with socket.socket(socket.AF_UNIX) as monitor:
        monitor.settimeout(180)
        monitor.connect(path)

        def response():
            data = b''
            while not data.endswith(b'(qemu) '):
                chunk = monitor.recv(65536)
                if not chunk:
                    raise RuntimeError('QEMU disconnected before command completion')
                data += chunk
            # HMP echoes editing escape sequences; only the lines after its echo matter.
            decoded = data.decode(errors='replace')
            return decoded.split('\r\n', 1)[-1].removesuffix('(qemu) ').strip()

        response()

        def command(text):
            monitor.sendall((text + '\n').encode())
            result = response()
            if re.search(r'error|failed|does not exist|not found|not support|cannot|could not|no block', result, re.I):
                raise RuntimeError(result)
            return result

        listing = command('info snapshots')
        names = {line.split()[1] for line in listing.splitlines()
                 if len(line.split()) >= 2 and (line.split()[0] == '--' or line.split()[0].isdigit())}
        if action == 'list':
            print(listing)
            return
        if action == 'restore' and name not in names:
            raise ValueError(f"snapshot '{name}' does not exist")
        print(f"[snapshot] {action}: {name}", flush=True)
        command(('savevm ' if action == 'save' else 'loadvm ') + name)
        print(f'[snapshot] complete: {name}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError) as exc:
        print(f'[snapshot] {exc}', file=sys.stderr)
        sys.exit(1)
