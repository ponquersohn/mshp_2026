#!/usr/bin/env python3
"""Explicit Diamorphine visibility exercise for the two disposable-lab helper processes."""
import argparse
import os
from pathlib import Path
import signal
import subprocess

HELPERS = ('telemetry-helper', 'knockd-helper')
INVISIBLE = 0x01000000  # This supplied Diamorphine's PF_INVISIBLE.
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('action', choices=('hide', 'reveal', 'status'))
args = parser.parse_args()
if os.geteuid() != 0:
    parser.error('run inside the lab guest as root')


def inspect(unit):
    pid = int((Path('/run/pingboard') / f'{unit}.pid').read_text().strip())
    if pid <= 1:
        raise RuntimeError(f'{unit}: invalid PID; restart app-data-start.service first')
    proc = Path('/proc') / str(pid)
    command = (proc / 'cmdline').read_bytes().split(b'\0')
    expected = f'/opt/pingboard/badseed/{unit}.py'.encode()
    if expected not in command:
        raise RuntimeError(f'{unit}: PID {pid} is not the expected lab Python process')
    # stat fields after the final ')' start at state (field 3); flags is field 9.
    flags = int((proc / 'stat').read_text().rpartition(')')[2].split()[6])
    return pid, bool(flags & INVISIBLE)


try:
    # Validate both targets before any module load or signal.
    targets = {unit: inspect(unit) for unit in HELPERS}
    if args.action == 'hide' and not Path('/sys/module/diamorphine').exists():
        module = '/diamorphine/diamorphine.ko'
        vermagic = subprocess.check_output(['modinfo', '-F', 'vermagic', module], text=True).split()[0]
        if vermagic != os.uname().release:
            raise RuntimeError(f'module targets {vermagic}; guest runs {os.uname().release}; rebuild first')
        subprocess.run(['insmod', module], check=True)
    if args.action == 'reveal' and not Path('/sys/module/diamorphine').exists():
        raise RuntimeError('Diamorphine is not present; do not send its control signal')
    for unit in HELPERS:
        pid, hidden = inspect(unit)
        if pid != targets[unit][0]:
            raise RuntimeError(f'{unit}: PID changed; retry with stable processes')
        if args.action != 'status' and hidden != (args.action == 'hide'):
            # Signal 31 is a TOGGLE in this module, not a normal stop/kill.
            os.kill(pid, 31)
            current_pid, hidden = inspect(unit)
            if current_pid != pid or hidden != (args.action == 'hide'):
                raise RuntimeError(f'{unit}: visibility change did not verify')
        print(f'{unit}: PID={pid} hidden={hidden}', flush=True)
except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
    parser.exit(1, f'STOP: {exc}\n')
