# LKMHunter rehearsal guide

## Prepare the exact case

Use only a private disposable VM. Building slides does not load the helper or any sample. The source and setup instructions are in the adjacent `../../../lkmhunter` checkout (relative to this directory).

Read its `README.md`, `docs/gdb-hunting.md` and `testbed/VALIDATION.md`. The older testbed README describes earlier prototypes; use the main README for the current CLI.

The opening case requires the hidden KoviD sample with an unchanged syscall table and visible ftrace evidence. Recorded validation is KoviD 4.0.1 on **6.8.0-147-generic**. It did not compile on the newer main guest kernel. Prepare and verify that specific compatible guest/sample pair or change the opening case to match the sample you can actually demonstrate.

Before the talk:

1. Prepare clean and infected snapshots of the same guest build. No compiling on stage.
2. Install LKMHunter in a guest-local `.venv`; prepare `bpftool`, `gdb`, matching baseline and optional DWARF.
3. Build and load the updated helper **inside the guest** using the tool's README. Sparse recovery requires its fault-contained read support.
4. Record `uname -a`, package/source versions, clean/infected scan JSON, raw ftrace, recovered regions and a GDB transcript.
5. Recheck after the last reboot/load: addresses, relocation and counts are not stable across runs.
6. Rehearse with a clock: opening 0–4; mechanisms 4–16; scan/recovery 16–28; GDB 28–34; interpretation 34–40; questions/buffer 40–45.

The main narrative needs an infected opening and a clean comparison for ftrace. A clearly labelled saved clean run avoids an on-stage VM swap if that is slow. Do not relabel historical tool validation as your current live output.

## Opening and scan

All commands run inside the guest from its LKMHunter checkout:

```bash
lsmod | grep -i kovid
test -d /sys/module/kovid; echo $?
sudo .venv/bin/lkmhunter scan syscalls --backend lkm_mem
# After explaining table hooks versus ftrace:
sudo .venv/bin/lkmhunter scan ftrace --json
```

Expected for the prepared case: absent normal module views, unchanged syscall table, one suspicious shared dispatcher. The **historical** 6.8 result was 462 matching entries and 22 functions sharing a dispatcher; do not promise identical counts or addresses.

Explain completed status, coverage, findings and diagnostics. Exit 0 is completed/no suspicious finding; 1 is completed/with suspicious findings; 2 is unavailable/failed/incomplete. Avoid `set -e` around a demonstration that expects exit 1. Legal tracing can also share callbacks; grouping is a lead, not a verdict.

## Source stops

Keep these open in the editor, not buried in terminal scrollback:

- `lkmhunter/scanners.py`: `SyscallScanner.scan`, original/actual/relocated pointer comparison.
- `testbed/rootkits/KoviD/src/kovid.c`: `_hide_mod`, module-list and sysfs removal.
- `testbed/rootkits/KoviD/src/sys.c`: `fh_ftrace_thunk`, getting the enclosing hook and changing `regs->ip`.

The callback excerpt is specific to the supplied sample/API. Do not infer that every ftrace callback redirects execution, or that modern syscall dispatch always reads sys_call_table.

## Recover and inspect

```bash
# Replace the placeholder with this run's dispatcher address.
DISPATCHER=0xREPLACE_ME
sudo .venv/bin/lkmhunter module find "$DISPATCHER" --backend lkm_mem
sudo .venv/bin/lkmhunter gdb --backend lkm_mem --symbols kallsyms
```

In GDB, replace the placeholder again:

```gdb
set $dispatcher = (unsigned long)0xREPLACE_ME
info symbol $dispatcher
x/24i $dispatcher
```

Use reported module regions to establish ownership. A nearby core symbol does not establish ownership, nor does a plausible string. In the recorded KoviD case, `hidden_from_module_list=false` despite missing normal views: stored links are not proof of actual list membership. Explain the whole chain.

Local GDB is a read-only memory bridge, distinct from `testbed/gdb.sh` and QEMU's CPU-debug stub. No CPU stop, breakpoints, stepping or real backtrace. `$pc` is synthetic. Live registers needed to resolve some indirect branches are unavailable. Repeat important reads and expect races.

Optional typed inspection uses a separate session with `--symbols vmlinux --vmlinux /path/to/matching/vmlinux`. Relocation is handled by the library. Set `$mod` to the recovered structure address, inspect `ptype /o struct module`, `name`, `state`, `mkobj.mod`. Scanner BTF does not automatically supply GDB types. Cut this section first if behind schedule.

## Preserve and qualify evidence

```bash
sudo .venv/bin/lkmhunter module dump "$DISPATCHER" \
  --backend lkm_mem --out-dir /var/tmp/mshp-evidence-01
```

Use a fresh output directory. Inspect the manifest for unreadable/zero-filled ranges: incomplete dump exits 2. Module-region export is not a full RAM acquisition. Record addresses, kernel identity, inputs, coverage and limitations together.

Helper, kcore, kallsyms and tracefs all remain inside the running-kernel trust boundary. External acquisition changes assumptions but still needs correct capture, symbols and interpretation. Do not claim this lab bypassed Secure Boot/lockdown: state which controls were actually enforced in the research guest.

After 90 seconds of failure, use a **labelled rehearsal recording/transcript**. Do not lower security on the host to rescue a demonstration. LiME/Volatility installation and full-image analysis are outside this slot. Afterward, shut down and restore the clean snapshot.
