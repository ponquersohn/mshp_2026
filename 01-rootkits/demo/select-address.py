#!/usr/bin/env python3
"""Select one unambiguous numeric address from an LKMHunter JSON report."""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', type=Path)
parser.add_argument('kind', choices=('syscall', 'ftrace'))
args = parser.parse_args()
report = json.loads(args.report.read_text())
if report.get('status') != 'complete':
    parser.error('scan is not complete; inspect diagnostics before continuing')
addresses = set()
for finding in report.get('findings', []):
    evidence = finding.get('evidence', {})
    value = None
    if args.kind == 'syscall' and finding.get('kind') in ('syscall_hook', 'syscall_dispatch_hook'):
        value = evidence.get('actual')
    elif args.kind == 'ftrace' and finding.get('kind') == 'ftrace_dispatcher':
        value = evidence.get('dispatcher')
    if isinstance(value, int) and value > 0:
        addresses.add(value)
    elif isinstance(value, str) and re.fullmatch(r'0x[0-9a-fA-F]+', value):
        addresses.add(int(value, 16))
if args.kind == 'syscall' and addresses:
    # Any detected destination is a lead; choose deterministically.
    print(hex(min(addresses)))
elif len(addresses) == 1:
    print(hex(addresses.pop()))
else:
    parser.error(f'expected one numeric dispatcher, found {len(addresses)}; inspect report')
