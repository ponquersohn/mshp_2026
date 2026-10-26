# Demo script — Diamorphine → KoviD → Singularity

Short stage companion to [script.md](script.md), which contains preparation,
builds, and rehearsal gates. Commands below run as **root inside the prepared
guest**, from `/opt/lkmhunter`, with `lkmhunter` installed in PATH.
Switch between the three prepared guest panes; do not load samples together.

Before presenting: sources/builds in `/root/workshop01`, clean scans saved in
`/root/mshp-demo`, matching kernel baseline available. Diamorphine and Singularity
have `lkm_mem` preloaded; KoviD uses kcore without it. KoviD's prepared build uses
`PROCNAME=mshpctl` and `UNHIDEKEY=0x1978101720260042`, on the rehearsed compatible
kernel (recorded: 6.8.0-147-generic). Prepare the fd-output helper as described in
[script.md](script.md). This condensed sequence still needs a full rehearsal.

In each clean guest, before the audience:

```bash
mkdir -p /root/mshp-demo
cd /opt/lkmhunter
uname -r
findmnt -T /root/workshop01 -o SOURCE,TARGET,FSTYPE
```

The disk examples below assume **ext4 mounted at `/`**. Replace
`/dev/REPLACE_DEVICE` once with the device printed by `findmnt`. Replace address
placeholders with this run's output; never reuse an address from another boot.
Use a fresh evidence directory for each rehearsal. Scan exit codes: 0 = complete,
no findings; 1 = complete, findings; 2 = unavailable/incomplete. Avoid `set -e`.

## Quick introduction — names, memory, instructions

**Say:** “`/proc` is a virtual filesystem: these files expose kernel information,
not ordinary files stored on disk. There is no standard `/kproc` interface here.
The two paths we need are `/proc/kallsyms` and `/proc/kcore`.”

```bash
awk '$3 == "_stext" { print; exit }' /proc/kallsyms
ls -lh /proc/kcore
```

**Say:** “Kallsyms maps names to live kernel virtual addresses: address, type,
name, and sometimes `[module]`. `T/t` means code; `D/d` means data. Zero addresses
can mean restricted disclosure. Missing names do not prove missing code.”

**Say:** “Kcore exposes live kernel memory as an ELF core file. Its huge apparent
size is not the amount of RAM. An ELF segment maps a virtual address to a file
offset; we cannot just seek to the kallsyms address. LKMHunter handles that.”

**Say:** “Our alternative is `/proc/lkm/mem`, provided by the preloaded helper.
That is a custom interface, not a standard Linux file. Both memory paths still
rely on the running kernel.”

In the **clean Diamorphine pane**, demonstrate names → bytes → instructions:

```bash
lkmhunter gdb --backend kcore --symbols kallsyms
```

**GDB:**

```gdb
p/x (unsigned long)&_stext
info address _stext
x/16bx &_stext
x/5i &_stext
quit
```

**Say:** “One address, viewed as bytes and then instructions. These are virtual
addresses. KASLR moves the core kernel between boots; the tool relocates the
matching baseline. Live kallsyms addresses already include that relocation.”

The bridge reads a running system: no CPU stop, stepping, breakpoints, kernel
function calls, or real backtrace. Kallsyms supplies names, not C structure types;
typed inspection needs matching DWARF/vmlinux. Repeat important reads.

## 1. Diamorphine — detect, repair directory visibility, unload

**Say:** “First, the straightforward lie: hide a file from directory listings
and unlink the module from the module list.”

The prepared build must use `MAGIC_PREFIX "diamorphine"` and the newer
**dispatcher-hooking** path for the five-byte repair below.

```bash
ls -l /root/workshop01/Diamorphine/diamorphine.ko
insmod /root/workshop01/Diamorphine/diamorphine.ko
ls -la /root/workshop01/Diamorphine
grep -i diamorphine /proc/modules
ls -ld /sys/module/diamorphine
```

**Expect:** hidden `.ko`, absent module-list entry, surviving sysfs entry.
**Say:** “Unlinking is not unloading. Code remains allocated and hooks still run.”

**Code:** [prefix/signals — diamorphine.h:47](../../lkmhunter/testbed/rootkits/Diamorphine/diamorphine.h),
[directory filtering — diamorphine.c:183](../../lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c),
[module unlink — diamorphine.c:321](../../lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:321).

```bash
lkmhunter scan syscalls --backend kcore --json > /root/mshp-demo/diamorphine.json
cat /root/mshp-demo/diamorphine.json
```

**Say:** “On this build, the syscall table can match while direct calls in
`x64_sys_call` point elsewhere. We compare both.” Show `site`, `expected`,
`actual`, baseline/current bytes, and complete coverage.

**Code:** [dispatcher patch — diamorphine.c:412](../../lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:412).

Copy a numeric **actual destination** from a directory-hook finding:

```bash
lkmhunter module find 0xREPLACE_ACTUAL
lkmhunter gdb --symbols kallsyms
```

**GDB:** substitute the same destination and its reported instruction site:

```gdb
x/5i 0xREPLACE_SITE
info symbol 0xREPLACE_ACTUAL
x/12i 0xREPLACE_ACTUAL
quit
```

**Say:** “The branch leads to allocated module code. Even without its symbol,
we can inspect the bytes. The recovered region bounds establish ownership.”

**Repair gate:** continue only for a complete scan with the two expected
`syscall_dispatch_hook` findings for `__x64_sys_getdents` and
`__x64_sys_getdents64`, each with a five-byte baseline instruction and resolved
numeric target. Otherwise use the validated repair block in [script.md](script.md)
or the saved rehearsal. These are raw live writes without CPU synchronization.

Copy the two **site addresses**, not their destinations:

```bash
lkmhunter copy 0xREPLACE_GETDENTS64_SITE 5 --backend lkm_mem --backup /root/mshp-demo/getdents64-backup.json
lkmhunter copy 0xREPLACE_GETDENTS_SITE 5 --backend lkm_mem --backup /root/mshp-demo/getdents-backup.json
```

**Say:** “Copy restores matching baseline bytes and verifies readback. We leave
the kill hook so the module's unhide command still works.” Stop if either write
fails; do not unload after an uncertain partial repair.

```bash
ls -la /root/workshop01/Diamorphine
lkmhunter scan syscalls --backend lkm_mem
```

**Expect:** file visible; only the kill hook remains.

```bash
kill -63 1
grep -i diamorphine /proc/modules
rmmod diamorphine
lkmhunter scan syscalls --backend kcore
```

**Expect:** module visible before unload, then complete scan without findings.
**Code:** [signal control — diamorphine.c:346](../../lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:346),
[cleanup — diamorphine.c:480](../../lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:480).

## 2. KoviD — another view of disk, then ftrace and memory

Switch to **KoviD pane**.
**Say:** “Now the syscall comparison stays unchanged. That check has a scope;
it does not certify the whole kernel.”

```bash
cd /opt/lkmhunter
insmod /root/workshop01/KoviD/kovid.ko
kill -s CONT 31337
printf 'hide-file=/root/workshop01/KoviD/kovid.ko\n' > /proc/mshpctl
ls -la /root/workshop01/KoviD
grep -i kovid /proc/modules
ls -ld /sys/module/kovid
lkmhunter scan syscalls --backend kcore
```

**Expect:** hidden file/module; complete syscall scan without changes in the
prepared case. The control interface is temporary; the signal reactivates it.

**Say:** “Try the filesystem's directory structures rather than ordinary `ls`.”

```bash
sync
debugfs -R 'ls -lp /root/workshop01/KoviD' /dev/REPLACE_DEVICE
debugfs -R 'dump /root/workshop01/KoviD/kovid.ko /root/mshp-demo/kovid-disk.ko' /dev/REPLACE_DEVICE
file /root/mshp-demo/kovid-disk.ko
```

**Expect:** entry visible and ELF recovered.
**Say:** “This is e2fsprogs `debugfs`, not `/sys/kernel/debug`. Without `-w` it
reads the filesystem; `dump` writes a separate output file. Live disk data can
lag caches, and reads still pass through this kernel.”

**Code:** [hide-file control — kovid.c:721](../../lkmhunter/testbed/rootkits/KoviD/src/kovid.c:721).

```bash
cat /root/mshp-demo/clean-ftrace.json
lkmhunter scan ftrace --json > /root/mshp-demo/kovid-ftrace.json
cat /root/mshp-demo/kovid-ftrace.json
```

**Say:** “Several functions lead to a shared ftrace callback. Legitimate tracing
can also share callbacks; follow this address to its owner.” Copy the suspicious
**dispatcher address**, not an original function address:

```bash
lkmhunter module find 0xREPLACE_DISPATCHER --backend kcore
lkmhunter module dump 0xREPLACE_DISPATCHER --backend kcore --out-dir /root/mshp-demo/kovid-memory
lkmhunter gdb --backend kcore --symbols kallsyms
```

**GDB:**

```gdb
info symbol 0xREPLACE_DISPATCHER
x/24i 0xREPLACE_DISPATCHER
quit
```

**Code:** [ftrace callback — sys.c:1187](../../lkmhunter/testbed/rootkits/KoviD/src/sys.c:1187).
Explain `container_of`: obtain the surrounding hook structure from its embedded
`ftrace_ops`; the callback then redirects the instruction pointer to the replacement.

**Say:** “Disk recovery gave us an ELF. Memory export gives runtime regions,
not automatically a reloadable module. Check the manifest for gaps and coverage.”

```bash
find /root/mshp-demo/kovid-memory -name '*.json' -exec cat {} \;
```

Optional talking point: the unhide secret is encrypted, but key material also
lives in memory. This timed path uses the **known lab key**, not a recovered one.
**Code:** [authorization — kovid.c:707](../../lkmhunter/testbed/rootkits/KoviD/src/kovid.c:707),
[key initialization — crypto.c:18](../../lkmhunter/testbed/rootkits/KoviD/src/crypto.c:18).

```bash
kill -s CONT 31337
printf 'unhide-lkm=1978101720260042\n' > /proc/mshpctl
grep -i kovid /proc/modules
rmmod kovid
lkmhunter scan ftrace
ls -la /root/workshop01/KoviD
```

**Expect:** unhide, successful unload, clean ftrace comparison, file visible.

## 3. Singularity — even the investigation output can lie

Switch to **Singularity pane**. Load the module only; skip its persistence installer.

```bash
cd /opt/lkmhunter
insmod /root/workshop01/Singularity/singularity.ko
ls -la /root/workshop01
grep -i singularity /proc/modules
ls -ld /sys/module/singularity
lkmhunter scan syscalls --backend kcore
```

**Say:** “This sample filters investigation inputs and output. A blocked kcore
read means we could not check, not that we found a clean system.” Describe the
actual result in this guest.

**Code:** [hidden patterns — hiding_directory_def.h:4](../../lkmhunter/testbed/rootkits/Singularity/include/hiding_directory_def.h:4),
[module/symbol hiding — hide_module.c:46](../../lkmhunter/testbed/rootkits/Singularity/modules/hide_module.c:46),
[self-defense hooks — selfdefense.c:506](../../lkmhunter/testbed/rootkits/Singularity/modules/selfdefense.c:506).

```bash
sync
debugfs -R 'ls -lp /root/workshop01' /dev/REPLACE_DEVICE | cat
```

**Expect:** prepared `Singularity` entry filtered in this exact pipeline.
If visible already, explain the actual conditions; do not claim universal filtering.

**Say:** “The write filter has an early return for `fd < 1`. Descriptor zero
means stdin by convention; it can still refer to a writable destination.”

**Code:** [fd check — hooks_write.c:603](../../lkmhunter/testbed/rootkits/Singularity/modules/hooks_write.c:603),
[our ptrace helper — debugfs_output.c:51](../../lkmhunter/utils/debugfs_output.c:51).

```bash
/root/mshp-debugfs-output debugfs -R 'ls -lp /root/workshop01' /dev/REPLACE_DEVICE | cat
```

**Say:** “The helper supplies a writable fd 0 and uses ptrace to change stdout
write arguments to zero. Same disk entries, different descriptor: the filter
skips the output.” Expect the missing entry to appear.

Optional full comparison:

```bash
python3 /opt/lkmhunter/debugfs_hunt.py /dev/REPLACE_DEVICE / --directory /root/workshop01 --bypass-output-filter
```

**Say:** “We loaded our memory helper before infection. It offers another memory
path, but it does not repair tracefs or escape the compromised kernel.”

```bash
ls -l /proc/lkm/mem
lkmhunter scan ftrace --json > /root/mshp-demo/singularity-ftrace.json
cat /root/mshp-demo/singularity-ftrace.json
```

Only proceed with a complete usable result and an identified numeric suspicious
callback. Filtering or ambiguous callbacks may block this step; use a labelled
saved run if the rehearsed live path fails.

```bash
lkmhunter module find 0xREPLACE_DISPATCHER --backend lkm_mem
lkmhunter module dump 0xREPLACE_DISPATCHER --backend lkm_mem --out-dir /root/mshp-demo/singularity-memory
```

**Expect:** recovered owner regions and coverage manifest; a printable module
name is not required. **Code:** [helper — lkm_mem.c:1](../../lkmhunter/modules/src/lkm_mem.c:1).

**Close:** “Three cases, three observation paths. Every result needs its scope
and coverage. Finding and unloading a rootkit does not establish that the machine
is clean: preserve evidence, rebuild from trusted media, rotate credentials.”

Singularity cleanup is a restart; do not attempt normal unload. After the demo,
power off and restore clean snapshots. After 90 seconds of trouble in any act,
use the labelled rehearsal transcript.
