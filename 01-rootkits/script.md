# Workshop 01 — presenter run-sheet

Present from this. Paste **one block at a time**.
**SAY** → commands → **EXPECT** → **SOURCE** when it helps.

All sample loading, memory reads, and repairs run **inside disposable guests**.
Host blocks only connect or stage this guide's address selector. Do not paste
GDB blocks into Bash. No demo slides are needed.

**Readiness:** commands below are derived from local source and recorded tool
validation, but this complete three-case sequence has not been rehearsed.
KoviD credential extraction is an optional analysis segment, not a working
extraction command. No VMs were changed while preparing this guide.

## Before the audience — stage once

Prepare three clean guest states, with a shell already open in each:

| Pane | Prepared kernel / state | Memory access |
| --- | --- | --- |
| **[D] Diamorphine** | Compatible dispatcher-hooking build; recorded on 7.3.0-9-generic | `lkm_mem` loaded before demo |
| **[K] KoviD** | Recorded compatible kernel: 6.8.0-147-generic | `kcore`; no `lkm_mem` |
| **[S] Singularity** | Exact compatible build must pass rehearsal | `lkm_mem` loaded before sample |

Use separate VMs or restore prepared snapshots between acts. Keep their SSH
ports with the pane labels. There is no checked-in three-VM launcher; do not
assume the default port selects the right guest.

**[HOST]** Connect to the existing main testbed (default port 2222):

```bash
cd /home/ponq/dev/lkmhunter/testbed
./ssh.sh
```

For a separately prepared guest, set its actual SSH_PORT when opening its pane.
The repository is shared at `/opt/lkmhunter`, per the
[testbed configuration](/home/ponq/dev/lkmhunter/testbed/config.sh:1).

**[HOST]** Stage the read-only address selector into each guest before infection
(use the port for that guest). Run for each prepared pane's port:

```bash
read -r -p 'Prepared guest SSH port: ' DEMO_SSH_PORT
scp -i /home/ponq/dev/lkmhunter/testbed/id_testbed -P "$DEMO_SSH_PORT" \
  /home/ponq/dev/mshp/01-rootkits/demo/select-address.py root@localhost:/root/mshp-select-address.py
```

**[D], [K], [S] — each clean guest, root Bash:**

```bash
cd /opt/lkmhunter
python3 -m venv /root/mshp-venv
/root/mshp-venv/bin/pip install -e .
mkdir -p /root/workshop01 /root/mshp-evidence
cat > /root/mshp-session.sh <<'BASH'
cd /opt/lkmhunter
export PATH="/root/mshp-venv/bin:$PATH"
export CASEDIR=/root/workshop01
export EVIDENCE
EVIDENCE=$(mktemp -d /root/mshp-evidence/run-XXXXXX)
set +e
set -o pipefail
pick_address() { python3 /root/mshp-select-address.py "$1" "$2"; }
BASH
source /root/mshp-session.sh
uname -r
command -v lkmhunter bpftool gdb debugfs strace cc
findmnt -T "$CASEDIR" -o SOURCE,TARGET,FSTYPE
```

**EXPECT:** all tools available; `/root/workshop01` is on ext4, not the 9p share.
Install missing tools before rehearsal. Ensure matching kernel baseline and
usable layout metadata; record clean scans before loading samples. Keep outputs
on guest-local disk. Scans exit 0 = complete/no finding, 1 = complete/findings,
2 = failed or incomplete. An empty report is not a clean result.

### Prepare Diamorphine — [D], before the audience

Use a guest-local source copy, change the hiding prefix, then build in the guest:

```bash
cp -a /opt/lkmhunter/testbed/rootkits/Diamorphine "$CASEDIR/Diamorphine"
cd "$CASEDIR/Diamorphine"
sed -i 's/^#define MAGIC_PREFIX .*/#define MAGIC_PREFIX "diamorphine"/' diamorphine.h
make clean
make
modinfo -F vermagic ./diamorphine.ko
cd /opt/lkmhunter
make -C "/lib/modules/$(uname -r)/build" M="$PWD/modules/src" obj-m=lkm_mem.o modules
# insmod modules/src/lkm_mem.ko
lkmhunter scan syscalls --backend kcore -v --json > "$EVIDENCE/clean-syscalls.json"
cat "$EVIDENCE/clean-syscalls.json"
```

**EXPECT:** matching vermagic, complete clean scan. Rehearse this guide with the
**dispatcher-hooking** build; the repair block intentionally rejects table hooks.
The prefix now hides `diamorphine.ko`; the checked-in default does not.

### Prepare KoviD — [K], before the audience

```bash
cp -a /opt/lkmhunter/testbed/rootkits/KoviD "$CASEDIR/KoviD"
cd "$CASEDIR/KoviD"
make clean
make DEPLOY=1 PROCNAME=mshpctl UNHIDEKEY=0x1978101720260042
modinfo -F vermagic ./kovid.ko
cd /opt/lkmhunter
lkmhunter scan syscalls --backend kcore --json > "$EVIDENCE/clean-syscalls.json"
lkmhunter scan ftrace --json > "$EVIDENCE/clean-ftrace.json"
cat "$EVIDENCE/clean-syscalls.json"
```

This chooses a known **lab** credential for reliable cleanup; it does not recover
one. If this build fails, resolve the exact toolchain issue before rehearsal;
do not rebuild on stage. Retain the exact unstripped build for optional analysis.
The memory helper must be absent in this pane. Confirm `/proc/lkm/mem` is absent.
If baseline discovery needs additional arguments, put the rehearsed defaults in
a shell wrapper before presenting rather than improvising them in each block.

### Prepare Singularity — [S], before the audience

```bash
cp -a /opt/lkmhunter/testbed/rootkits/Singularity "$CASEDIR/Singularity"
cd "$CASEDIR/Singularity"
make
modinfo -F vermagic ./singularity.ko
cd /opt/lkmhunter
make -C "/lib/modules/$(uname -r)/build" M="$PWD/modules/src" obj-m=lkm_mem.o modules
insmod modules/src/lkm_mem.ko
cc -Wall -Wextra -O2 utils/debugfs_output.c -o /root/mshp-debugfs-output
lkmhunter scan ftrace --json > "$EVIDENCE/clean-ftrace.json"
```

Load only the `.ko` during the demo; do not run its persistence installer.
Rehearse that the preloaded helper remains usable after infection. Retain a
labelled saved transcript for each act. Reset to clean snapshots after rehearsal;
repeat the clean preparation state before presenting.

## Timing

| Minute | Segment |
| --- | --- |
| 0–10 | Prep slides, syscall trace, and KASLR terminal stop |
| 10–20 | Diamorphine: detect, repair visibility, unhide, unload |
| 20–30 | KoviD: debugfs, ftrace, owner and export |
| 30–38 | Singularity: deception, fd=0, memory helper |
| 38–40 | Close |

Credential extraction is overflow. After 90 seconds of failure use the labelled
saved run. Never turn an unavailable scan into a claim of no hooks.

---
Prep slides: [slides.md](slides.md). Follow the slide order through the KASLR
terminal stop, then begin Diamorphine at minute 10. The notes below supply
extra wording; they are not additional segments.

## Prep: frame the investigation

**Say:** “Today we are investigating a Linux machine where we already know a
rootkit was loaded. The question is: what evidence can we still find when the
usual tools do not show it?”

Explain a rootkit as software or techniques used to conceal activity and
maintain control after access has been obtained. Distinguish hiding, gaining
privileges, and surviving a reboot: they are separate capabilities.

**Example:** “A process keeps running, but disappears from `ps`. The rootkit
has changed what you can see, not stopped the process. It may hide itself or
another payload.” The name refers historically to privileged control; a rootkit
does not necessarily obtain root access itself.

Do not mention user space or kernel space yet; the next two slides introduce
them, and “So what is a rootkit, really?” comes back to this definition.

**Transition:** “To see how a system can lie to you, start with how a program
asks the kernel for anything at all.”

## Prep: user space and kernel space

**Say:** “Your shell, applications, and services run in user space. The kernel
manages the resources they share: CPU time, memory, files, and devices. The CPU
enforces a privilege boundary between application code and kernel code.”

User space and kernel space are execution domains, not separate physical
machines. Processes normally have isolated virtual address spaces; deliberate
sharing is possible. Even a root shell runs in user space: user identity and
CPU execution privileges are different concepts.

**Transition:** “How does a program ask the kernel to do something it cannot
do directly? Through a system call.”

## Prep: user space → syscall → kernel

**Sketch:** application → library wrapper → syscall boundary → kernel handler.

**Say:** “A process cannot directly perform every privileged operation. It asks
the kernel to do things such as opening files or creating processes through a
system call.”

Separate a library function from a syscall: one library call does not always
correspond to exactly one syscall. Introduce the syscall number, arguments,
and return value without teaching register conventions.

Process, file, and module tools receive data through kernel interfaces. Start
with the normal request and response before introducing how it can be altered.

**SAY:** “Watch an ordinary program ask the kernel to list a directory.”

```bash
strace -e trace=openat,getdents64 ls ~/
```

**EXPECT:** directory opens and `getdents64` calls. Explain only one call.

**Transition:** “Our tools show us the answers they receive. What happens when
someone deliberately changes those answers?”

## Prep: so what is a rootkit, really?

**Say:** “Same definition as a minute ago, but now we can place it. A
user-space rootkit replaces or intercepts one program. A kernel rootkit changes
the answers the kernel gives, so every program that asks sees the same lie.”

Not every rootkit is a kernel module, and not every module is malicious. Our
three cases are kernel rootkits loaded as modules: Diamorphine → KoviD →
Singularity. A module is also the normal mechanism for legitimate kernel
extensions and drivers.

**Transition:** “So how does that code get into the kernel in the first place?”

## Prep: a module brings code into the kernel

**SOURCE:** [mini module](demo/mini-module/mshp_hello.c).
Open the file in the editor; source discussion is the default for this slide.

Walk through these four pieces:

1. `message`: module data, stored alongside its code in kernel memory.
2. `mshp_hello_init`: loader entry point; `0` means successful initialization.
3. `mshp_hello_exit`: cleanup entry point for normal unloading.
4. `module_init` / `module_exit`: register those functions; there is no `main()`.

**SAY:** “This is ordinary C, but it runs inside the kernel. `pr_info` writes
to the kernel log, not a terminal. This example only logs messages. A driver
could register device operations; a rootkit could register interception code.”

`__init` marks initialization code that can be freed after a successful load;
the module's persistent code/data can remain until unload. `MODULE_LICENSE`
is metadata, not a signature or a safety verdict. `struct module` is managed
by the kernel; we do not need to define it in this source.

### Optional rehearsal: build and load in a disposable guest

Stage this directory in `/root/workshop01/mini-module` in a clean guest before
the audience. Build against that guest's configured kernel headers/build tree;
resolve signature policy and missing headers during preparation. Do not use the
host's kernel build to prepare a module for a different guest.

**[D], clean guest, root Bash:**

```bash
cd /root/workshop01/mini-module
make -C "/lib/modules/$(uname -r)/build" M="$PWD" modules
modinfo ./mshp_hello.ko
insmod ./mshp_hello.ko
grep '^mshp_hello ' /proc/modules
ls -ld /sys/module/mshp_hello
dmesg | tail -n 10
rmmod mshp_hello
dmesg | tail -n 10
cd /opt/lkmhunter
```

**EXPECT:** successful load, a visible module and sysfs directory, a hello log
entry, then a goodbye entry on unload. Commands are a rehearsal option; the
timed slide needs only the source walkthrough. No module was loaded while
preparing this material.

Build reference: [Linux external modules](https://docs.kernel.org/kbuild/modules.html).

**Transition:** “Loading gives us kernel code. How does that code get onto a
path another operation will execute?”

## Prep: hooks and the tracing landscape

**Say:** “A hook is a point where we can observe execution or change what happens.
The mechanism matters: observing a call and redirecting a call are different.”

**Diagram:** read each row left to right as a timeline. Normally the caller
reaches the original function and receives its result. In the wrapper example,
hook code sees the arguments, calls the original, then gets control back to
filter the output before returning. The two red boxes are two stages of one
wrapper, not necessarily separate hooks.

**Example:** “The kernel reads a directory normally. The wrapper removes a
chosen name from the returned entries. The caller receives a plausible but
incomplete answer; the file itself still exists.” A full replacement could skip
the original entirely. An observation-only hook can leave the result unchanged.

| Mechanism | Explanation for this workshop | Role today |
| --- | --- | --- |
| `LD_PRELOAD` | The dynamic loader loads a library before others, allowing interposition of selected dynamically resolved library functions. | Connects to user-space rootkits; no live demo. |
| Direct patching | Classic syscall-table pointer replacement or instruction patching changes kernel control flow. Modern dispatch may bypass the syscall table. | Supplied Diamorphine patches dispatcher calls. |
| `ptrace` | A process-control interface used by debuggers and syscall tracers to inspect or control another process. | Returns in the fd=0 workaround. |
| ftrace | Kernel tracing infrastructure with callbacks at supported instrumented functions; suitable configurations also allow redirection. | The lead used in our investigation. |
| eBPF | Programs verified and loaded into the kernel, attached at supported points for tasks including tracing and networking. | Context only; no eBPF programming segment. |

These are legitimate mechanisms, not synonyms for rootkits. Their capabilities,
permissions, and attachment points differ. An LKM is a way to load kernel code;
it can use hooking mechanisms, but is not itself a synonym for a hook.

**SAY:** “In user space, LD_PRELOAD can put our library function in front of
the normal one—for example, to filter directory entries returned by readdir.
That changes what an affected process sees without changing the kernel.
The classic kernel approach changes pointers or instructions directly.
Ftrace offers registered callbacks in kernel functions. Ptrace lets a user-space
tracer control selected processes. With eBPF, a user-space loader can attach
verified programs that run at supported kernel hooks, without our own module.”

Present this as a range of approaches, not an old-to-new timeline: ptrace is
older than ftrace, and eBPF is established. “From user space” describes loading
and control, not where the BPF program executes. BPF can observe or affect
operations as permitted by its program type, attachment point, helpers, verifier,
and policy; it does not grant arbitrary kernel instruction patching. Ftrace
callbacks also do not inherently redirect execution.

LD_PRELOAD is library interposition, not syscall replacement: statically linked
programs and direct syscalls do not use those interposed library calls. Even
dynamically linked programs can use internal/bound calls that are not interposed.
Secure-execution mode restricts preload behavior. Do not imply this affects every
process or changes the kernel's own answer.
Source: [dynamic linker and LD_PRELOAD](https://man7.org/linux/man-pages/man8/ld.so.8.html).

Sources: [ftrace callbacks](https://docs.kernel.org/trace/ftrace-uses.html),
[ptrace](https://man7.org/linux/man-pages/man2/ptrace.2.html),
[BPF design](https://docs.kernel.org/bpf/bpf_design_QA.html).

Explain the narrow syscall-table check: it compares table pointers with an
expected baseline. Other interception paths can leave those pointers unchanged;
the table is not a complete description of kernel execution.

**Transition:** “A hook is a pointer to somebody else's code. So what exactly
is a pointer?”

## Prep: addresses, symbols, and pointers

**Say:** “An address is a location in memory. A symbol is just a name for one,
like `sys_call_table`. A pointer is a value that holds an address. Follow this
one: the table has a slot for `getdents64`, the slot holds an address, and at
that address is the code that lists directories.”

Point at the red path: “A hook doesn't need to touch the original code. It
rewrites the pointer, and everyone who follows it ends up in the rootkit.”

Keep the slide theoretical. The addresses on the diagram are illustrative, not
captured; 217 is `getdents64` on x86-64. Do not mention `/proc` here: kallsyms
and kcore get their own slide after vmlinux. Classic Diamorphine-style hooks
rewrite this slot; the supplied newer build patches direct calls in
`x64_sys_call` instead.

**Virtual versus physical — notes, not a page-table lesson:** CPU memory
accesses use virtual addresses. The MMU uses page-table mappings (and cached
translations) to reach physical memory. For this mapped kernel code, there is
RAM backing, but the kallsyms value is not a physical RAM offset. Arbitrary
virtual addresses can be unmapped or device-backed. In our VM, “physical” means
guest physical memory; host backing adds another translation layer. Do not
subtract a guessed constant from arbitrary kernel or module pointers. User/kernel
space describes access domains; virtual/physical describes addressing.

Source: [Linux page tables and MMU](https://docs.kernel.org/mm/page_tables.html).

**Transition:** “To spot a rewritten pointer, we first need to know what it
should be: the kernel as built.”

## Prep: vmlinux — the kernel before it booted

**Say:** “`vmlinuz` in `/boot` is what the bootloader loads: compressed.
`vmlinux` is the plain ELF: the code bytes as built, a symbol table, and with a
debug package, DWARF types. System.map is just names and link-time addresses.
BTF gives types and struct layouts, but no addresses.”

This is the known-good baseline: what syscall pointers and instructions should
look like. It is only useful if it matches the running build; build IDs must
match, and banners and consistent KASLR anchors add validation. lkmhunter looks
in standard local debug/boot locations and can run `extract-vmlinux`; it
downloads nothing.

**Transition:** “That is what the kernel should be. Now the live side: how do
we find what it actually is?”

## Prep: kallsyms and kcore — what we see, and why

**Say:** “Two files in `/proc` give us kernel space. Kallsyms is the kernel's own
symbol table: every function and variable it knows, including loaded modules.
It exists so the kernel can print backtraces and so tracers can find
functions. Kcore is kernel memory wrapped in an ELF core file, so a debugger
can open the running kernel like a crash dump.”

Read the kallsyms line as: virtual address, symbol type, symbol name.
`_stext` marks the start of kernel text; do not call it. The example address is
illustrative and deliberately matches the KASLR slide.

Point out the `[module]` column on module symbols and the type letters
(`T`/`t` text, `D`/`d` data; lowercase is local). Without root, or with
`kptr_restrict`, kallsyms addresses read as zero: that is restricted visibility,
not proof of anything. Kcore's size is the mapped address range, not RAM.

**Say:** “Both answers come from the running kernel. That is convenient, and it
is also the weakness: a rootkit lives in the same place.” Singularity returns to
this point.

**Transition:** “Kallsyms gives me an address, kcore holds the bytes. Getting
from one to the other costs a little maths.”

## Prep: kernel memory comes with a maths tax

**Say:** “Kallsyms gives me `0xffffffff81234560`. Can I just seek there in
kcore? That number is about 16 exabytes. Kcore is big, 128 terabytes on paper,
but not that big. It's a virtual address, and kcore is an ELF file: its segment
table says which address range lives at which file offset. Find the segment,
subtract its start, add its offset, read the bytes.”

Keep the physical-address explanation above in reserve. The two slides establish
names and memory, then the practical mapping problem. KASLR gets its own
explanation and measurement later; mention the dependency here without a detour.

**Background, not for the slide — how lkmhunter does this:** “I work with kernel virtual addresses.
With kcore, lkmhunter finds the containing ELF load segment and converts that
address into a file offset, then reads the bytes. With a matching baseline, it
also validates this boot's KASLR slide and relocates baseline symbols. Those
are two separate pieces of bookkeeping the tool handles for us.”

Keep these three mappings distinct:

- CPU access: virtual address → page-table translation → physical memory.
- kcore read: virtual address → ELF segment → file offset.
- Baseline comparison: image symbol address + validated slide → runtime address.

For a containing file-backed ELF segment, the kcore reader computes
`p_offset + (address - p_vaddr)`. This is not a physical-address conversion.
Live kallsyms addresses are already runtime addresses: do not add the slide
again. Core-kernel relocation does not provide a universal module/heap offset.
The GDB bridge can load matching vmlinux symbols with relocation, or use live
kallsyms symbols. Permissions, accessible memory, and matching inputs still
determine what can be inspected.

Local implementation: [ELF memory reader](/home/ponq/dev/lkmhunter/lkmhunter/memory.py:30),
[runtime symbol resolution](/home/ponq/dev/lkmhunter/lkmhunter/session.py:200),
[GDB symbol relocation](/home/ponq/dev/lkmhunter/lkmhunter/gdb_bridge.py:326).

### Optional live example — replace the static explanation, not an extra segment

**[D], clean prepared guest, before loading any sample:**

```bash
awk '$3 == "_stext" { print; exit }' /proc/kallsyms
```

**EXPECT:** one line with the guest's actual address, type, and name. If the
address is zero or the symbol is unavailable, explain the visibility limit and
use the labelled illustrative example above. Do not change disclosure policy on stage.

If the prepared memory helper and GDB bridge have passed rehearsal:

```bash
lkmhunter gdb --backend lkm_mem --symbols kallsyms
```

**Inside GDB:**

```gdb
set $entry = (unsigned long)&_stext
p/x $entry
info symbol $entry
x/16bx $entry
x/5i $entry
quit
```

**SAY:** “Same virtual address: first a symbol name, then bytes, then those
bytes interpreted as machine instructions. We have read memory, not found a
physical RAM address.” Compare the printed address with this boot's kallsyms.
This read-only bridge does not stop CPUs or support stepping/breakpoints;
`_stext` marks a text boundary, not necessarily a useful function entry.
Allow at most 45 seconds; use the slide if setup or reads are unavailable.

### C vocabulary — introduce only as needed in later source excerpts

- A `struct` groups related fields in memory.
- A pointer stores an address of data or code.
- A function pointer stores a function address; a callback is registered to run
  at a chosen event or point.
- A `struct module` describes a loaded module and its memory regions; the layout
  depends on the kernel build.

**Transition:** “Later, we will find a callback address and ask which module
owns that region of memory.” Introduce `container_of` only in the actual source.

**Transition:** “Put kallsyms next to vmlinux: same `_stext`, two different
numbers. Why?”

## Prep: KASLR — why the addresses differ, and how to beat it

**Say:** “So now we can name a symbol, find its address, and read the bytes at
that address. Then the kernel makes it harder: every boot it picks a new random
base, so the addresses in vmlinux are wrong for this boot. That's KASLR, and it
exists so an exploit can't hard-code where things are.”

**Say:** “But look at the picture: the whole image moves together. `_stext` and
`sys_call_table` move by exactly the same amount. Find one known address in this
boot, subtract the vmlinux address, and you have the slide for every core
symbol. As root I can read kallsyms, so KASLR stops attackers guessing, not me
measuring.”

Keep the scope tight: the slide relocates core-kernel symbols only. Module and
heap addresses are not derived by adding it to arbitrary pointers. Live
kallsyms values are already runtime addresses: do not add the slide again.

**Transition:** “Once we know the slide, we can do the maths.”

## Prep: do the maths — two images of one kernel

**Say:** “Add the slide to vmlinux and we have the kernel as it should be in
this boot. Read the live kernel through kcore and we have it as it is. Two
images of the same kernel that should line up. Where they don't, we have a
lead.”

A match covers only what was compared. Missing input is not a completed check,
and a completed check is not “no findings”.

**Transition:** “Now imagine doing that by hand, for every slot, every boot.”

## Prep: that's why I built lkmhunter

**Say:** “That's why I built lkmhunter: a set of tools that make it easier to
detect, and sometimes disarm, running rootkits. It finds the matching vmlinux,
measures the slide, reads kcore, and does the comparison. It can follow an
ftrace callback to the module that owns it, even when the module has erased its
name. And sometimes it can write the original bytes back over a hook.”

Keep “sometimes” honest: restoring bytes is not a cleanup guarantee, and the
scanners report evidence, not proof of a clean system.

**Transition:** “Let's measure the slide on our VM.”

---

## Prep terminal stop — KASLR: measure the slide **[D], before infection**

Slide cue: the **LIVE DEMO** slide, “Let's get our hands dirty” (samples on the
left, meme on the right). Budget 70 seconds, then stay in the terminal and
continue with Diamorphine; the slide stays up as the map of the three samples.

**SAY:** “The address in our kernel image is not necessarily the address used
this boot. We need a matching image and the relocation before comparing memory.”

```bash
cat /proc/cmdline
sysctl kernel.kptr_restrict
python3 - <<'PYCODE'
from lkmhunter import KernelSession
with KernelSession.open() as session:
    # Force the baseline's identity checks before comparing symbols.
    session.baseline
    slide = session.kaslr_offset
    print('Symbol             Image address       Runtime address     Difference')
    for name in ('_stext', '_etext'):
        image = session.baseline_symbols.get(name)
        live = session.live_symbols.get(name)
        if image is None or live is None or not image.address or not live.address:
            raise SystemExit('STOP: core symbol addresses unavailable')
        delta = live.address - image.address
        print(f'{name:18} {image.address:#018x}  {live.address:#018x}  {delta:#x}')
        if delta != slide:
            raise SystemExit('STOP: inconsistent symbol relocation')
    print(f'Validated core-kernel slide: {slide:#x}')
PYCODE
```

**EXPECT:** both core symbols have the same difference. A nonzero difference
shows relocation relative to this matching image. Zero can be legitimate;
check the actual boot configuration. Restricted/zero symbol addresses mean
this observation is unavailable, not that KASLR is off.

**SAY:** “For these core symbols, add this slide to the image address. It is not
a universal offset for module and heap allocations.”

Prepare a clean KASLR-enabled guest for this stop. The recorded main testbed
was returned to `nokaslr`; do not assume the current VM randomizes addresses.
For a second-boot comparison, run this block during rehearsal across independent
boots of the same kernel and save labelled transcripts. Repeated reads in one
boot do not show randomization, and restoring the same running snapshot need
not change addresses. Do not reboot the presentation guest mid-demo.

**SOURCE:** [baseline matching](/home/ponq/dev/lkmhunter/lkmhunter/session.py:134),
[slide cross-check](/home/ponq/dev/lkmhunter/lkmhunter/symbols.py:51),
[session relocation](/home/ponq/dev/lkmhunter/lkmhunter/session.py:200),
[Linux KASLR explanation](https://docs.kernel.org/security/self-protection.html#kernel-address-space-layout-randomization-kaslr).

---

## 10–12 · Diamorphine — make it disappear **[D]**

**SAY:** “We start with a file we can see. Loading its module changes directory
enumeration; the file stays on disk.”

```bash
cd "$CASEDIR/Diamorphine"
ls -l ./diamorphine.ko
insmod ./diamorphine.ko
ls -la .
grep -i diamorphine /proc/modules
ls -ld /sys/module/diamorphine
```

**EXPECT:** `.ko` disappears from the listing, module absent from `/proc/modules`,
sysfs entry remains. `grep` exit 1 here is expected. If the file stays visible,
check the prepared prefix; do not claim the demonstration worked.

**SOURCE:** [prefix and signal numbers](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.h:47),
[directory filtering](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:183),
[module unlinking](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:321).

**SAY:** “Different views retain different clues. Unlinking from the module
list did not remove the sysfs object.”

## 12–16 · Find the changed syscall path **[D]**

```bash
cd /opt/lkmhunter
lkmhunter scan syscalls --backend lkm_mem --json > "$EVIDENCE/diamorphine-before.json"
cat "$EVIDENCE/diamorphine-before.json"
D_HOOK=$(pick_address "$EVIDENCE/diamorphine-before.json" syscall)
if [[ -n "$D_HOOK" ]]; then
    lkmhunter module find "$D_HOOK" --backend lkm_mem
fi
```

**EXPECT:** for the rehearsed newer build, changed direct transfers for
`getdents`, `getdents64`, and `kill`. The table may still match. Show `site`,
`expected`, `actual`, bytes, coverage, and owner region containing the destination.

**SAY:** “This build changed direct calls inside the syscall dispatcher.
The scanner compares those instructions as well as the syscall table.”

**SOURCE:** [Diamorphine dispatcher patch](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:412),
[scanner comparison](/home/ponq/dev/lkmhunter/lkmhunter/scanners.py:82).

## 16–18 · Write the original directory calls back **[D]**

**SAY:** “This is the blunt repair: put the matching original bytes back.
We leave the kill control hook in place so we can still unhide the module.”

The following block selects only the two five-byte directory-dispatch findings,
prints the repair plan, and invokes the existing `copy` command with backups.
It rejects partial scans and other hook layouts. This is a raw live write with
no CPU synchronization; use the rehearsed disposable guest.

```bash
python3 - "$EVIDENCE/diamorphine-before.json" <<'PY'
import json, subprocess, sys
from pathlib import Path
report_path = Path(sys.argv[1])
report = json.loads(report_path.read_text())
if report['status'] != 'complete':
    raise SystemExit('STOP: incomplete scan')
wanted = {'__x64_sys_getdents', '__x64_sys_getdents64'}
repairs = [f['evidence'] for f in report['findings']
           if f['kind'] == 'syscall_dispatch_hook' and f['evidence']['name'] in wanted]
if len(repairs) != 2 or {e['name'] for e in repairs} != wanted:
    raise SystemExit('STOP: expected exactly the two directory-dispatch findings')
for e in repairs:
    if len(bytes.fromhex(e['baseline_bytes'])) != 5 or not isinstance(e['actual'], int):
        raise SystemExit('STOP: unexpected instruction or unresolved target')
for e in repairs:
    print(e['name'], hex(e['site']), e['actual_bytes'], '->', e['baseline_bytes'], flush=True)
    subprocess.run(['lkmhunter', 'copy', hex(e['site']), '5', '--backend', 'lkm_mem',
                    '--backup', str(report_path.parent / (e['name'] + '-backup.json'))], check=True)
PY
```

**EXPECT:** two successful readback-verified writes. If either fails, stop this
act and use the saved run or restore its snapshot. Do not continue to unload
with an uncertain partial repair.

```bash
ls -la "$CASEDIR/Diamorphine"
lkmhunter scan syscalls --backend lkm_mem --json > "$EVIDENCE/diamorphine-after-repair.json"
cat "$EVIDENCE/diamorphine-after-repair.json"
```

**EXPECT:** `.ko` visible again; directory hooks gone, `kill` finding remains.
This is repaired enumeration, not full removal.

**SOURCE:** [copy and readback implementation](/home/ponq/dev/lkmhunter/lkmhunter/copy.py:1).

## 18–20 · Unhide, unload, check **[D]**

```bash
kill -63 1
grep -i diamorphine /proc/modules
rmmod diamorphine
lkmhunter scan syscalls --backend lkm_mem
ls -ld /sys/module/diamorphine
```

**EXPECT:** visible after signal, removed after unload, complete scan without
findings, sysfs path absent. The final `ls` error is expected.

**SOURCE:** [signal control](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:346),
[exit cleanup](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:480).

**SAY:** “Next: a sample that leaves these syscall checks unchanged.”
Switch to **[K]**, not the same infected/repaired VM.

---

## 20–22 · KoviD — hidden file, unchanged syscalls **[K]**

```bash
cd /opt/lkmhunter
uname -r
test ! -e /proc/lkm/mem && echo 'No memory helper in this guest'
ls -l "$CASEDIR/KoviD/kovid.ko"
insmod "$CASEDIR/KoviD/kovid.ko"
kill -s CONT 31337
printf 'hide-file=%s/KoviD/kovid.ko\n' "$CASEDIR" > /proc/mshpctl
ls -la "$CASEDIR/KoviD"
grep -i kovid /proc/modules
ls -ld /sys/module/kovid
lkmhunter scan syscalls --backend kcore
```

**EXPECT:** release build hidden from normal module views; configured file
omitted; complete syscall scan without changes in this prepared case.
The signal activates a temporary control interface; reactivate before later
control commands. Its lifetime comes from the selected build.

**SAY:** “We changed the observation path for Diamorphine. Let's do it again,
this time by reading directory entries from the filesystem image.”

## 22–24 · debugfs: read on-disk entries and recover the ELF **[K]**

```bash
DISK_DEVICE=$(findmnt -n -o SOURCE -T "$CASEDIR")
DISK_TYPE=$(findmnt -n -o FSTYPE -T "$CASEDIR")
DISK_MOUNT=$(findmnt -n -o TARGET -T "$CASEDIR")
printf 'Device=%s filesystem=%s mount=%s\n' "$DISK_DEVICE" "$DISK_TYPE" "$DISK_MOUNT"
```

**EXPECT:** ext4 mounted at `/`. The following paths assume that prepared layout;
if it differs, stop and fix the runbook before the session.

```bash
if [[ "$DISK_TYPE" == ext4 && "$DISK_MOUNT" == / ]]; then
    sync
    debugfs -R 'ls -lp /root/workshop01/KoviD' "$DISK_DEVICE"
    debugfs -R "dump /root/workshop01/KoviD/kovid.ko $EVIDENCE/kovid-disk.ko" "$DISK_DEVICE"
    file "$EVIDENCE/kovid-disk.ko"
    sha256sum "$EVIDENCE/kovid-disk.ko"
fi
```

**EXPECT:** raw directory entry present and recovered file recognized as ELF.
`debugfs` is read-only without `-w`; `dump` writes a separate output file.

**SAY:** “This is e2fsprogs debugfs, not `/sys/kernel/debug`. It avoids the normal
directory enumeration path. Live on-disk data can lag cached data, and all I/O
still passes through this kernel.”

**SOURCE:** [KoviD file-control commands](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/kovid.c:721),
[our raw-directory comparison](/home/ponq/dev/lkmhunter/debugfs_hunt.py:91).

## 24–28 · Follow ftrace into its owning module **[K]**

```bash
cat "$EVIDENCE/clean-ftrace.json"
lkmhunter scan ftrace --json > "$EVIDENCE/kovid-ftrace.json"
cat "$EVIDENCE/kovid-ftrace.json"
K_DISPATCHER=$(pick_address "$EVIDENCE/kovid-ftrace.json" ftrace)
if [[ -n "$K_DISPATCHER" ]]; then
    lkmhunter module find "$K_DISPATCHER" --backend kcore --json > "$EVIDENCE/kovid-owner.json"
    cat "$EVIDENCE/kovid-owner.json"
    lkmhunter module dump "$K_DISPATCHER" --backend kcore --out-dir "$EVIDENCE/kovid-memory"
fi
```

**EXPECT:** a shared callback, owner regions containing its address, export
manifest. Use actual counts; recorded counts and addresses are not constants.
A shared dispatcher is a lead; legitimate tracing can produce similar grouping.

```bash
find "$EVIDENCE/kovid-memory" -name '*.json' -exec cat {} \;
```

**EXPECT:** inspect `complete`, `gaps`, region bounds, and backend. A gap is not
proof of zero-valued memory. Stored list links do not prove live membership.

**SAY:** “The on-disk export was an ELF module. This export is runtime memory
regions, not automatically a reloadable `.ko`. We recovered the callback owner
without loading our memory helper.”

**SOURCE:** [ftrace redirection callback](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/sys.c:1187),
[ftrace grouping](/home/ponq/dev/lkmhunter/lkmhunter/scanners.py:157),
[module dump manifest](/home/ponq/dev/lkmhunter/lkmhunter/scanners.py:374).

## 28–30 · Inspect, explain the secret, unload **[K]**

Generate the GDB commands with this run's address, then launch:

```bash
if [[ -n "$K_DISPATCHER" ]]; then
    printf 'set $dispatcher = (unsigned long)%s\ninfo symbol $dispatcher\nx/24i $dispatcher\n' \
        "$K_DISPATCHER" > "$EVIDENCE/kovid.gdb"
    cat "$EVIDENCE/kovid.gdb"
    lkmhunter gdb --backend kcore --symbols kallsyms
fi
```

**[GDB]** Load the generated file (this avoids entering its random path):

```gdb
python import os; gdb.execute('source ' + os.environ['EVIDENCE'] + '/kovid.gdb')
detach
quit
```

**EXPECT:** readable instructions even if a useful symbol is absent. Nearby
symbol labels do not establish ownership; use recovered bounds. This memory
bridge cannot stop CPUs, step, call kernel functions, or show live registers.

**SAY:** “KoviD keeps the unhide credential encrypted. It also keeps enough
material available to decrypt it. That gives us an analysis exercise.”

**SOURCE:** [credential comparison](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/kovid.c:585),
[unhide authorization](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/kovid.c:707),
[encryption and clearing original value](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/kovid.c:1027),
[runtime AES key](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/crypto.c:18).

Use the known lab credential in the timed path:

```bash
kill -s CONT 31337
printf 'unhide-lkm=1978101720260042\n' > /proc/mshpctl
grep -i kovid /proc/modules
rmmod kovid
lkmhunter scan ftrace
ls -la "$CASEDIR/KoviD"
```

**EXPECT:** module becomes visible, unload succeeds, clean ftrace comparison and
file visibility return. Confirm these outcomes during rehearsal. Switch to **[S]**.

---

## 30–32 · Singularity — show the lie **[S]**

```bash
cd /opt/lkmhunter
uname -r
ls -l "$CASEDIR/Singularity/singularity.ko"
insmod "$CASEDIR/Singularity/singularity.ko"
ls -la "$CASEDIR/Singularity"
grep -i singularity /proc/modules
ls -ld /sys/module/singularity
lkmhunter scan syscalls --backend kcore
```

**EXPECT:** hiding in the rehearsed build; kcore may be unavailable or filtered.
Explain the actual status. A read failure means “could not check,” not “clean.”

**SAY:** “This sample attacks more than enumeration. It filters investigation
inputs and even the output of tools reading disk structures.”

**SOURCE:** [hidden patterns](/home/ponq/dev/lkmhunter/testbed/rootkits/Singularity/include/hiding_directory_def.h:4),
[module and symbol removal](/home/ponq/dev/lkmhunter/testbed/rootkits/Singularity/modules/hide_module.c:46),
[self-defense hooks](/home/ponq/dev/lkmhunter/testbed/rootkits/Singularity/modules/selfdefense.c:506).

## 32–35 · Same disk, different descriptor **[S]**

```bash
DISK_DEVICE=$(findmnt -n -o SOURCE -T "$CASEDIR")
findmnt -T "$CASEDIR" -o SOURCE,TARGET,FSTYPE
sync
debugfs -R 'ls -lp /root/workshop01' "$DISK_DEVICE" | cat
```

**EXPECT:** compare with the prepared known entry `Singularity`. This step
intentionally uses a pipe, where this sample's output filtering matters.
If the entry already appears, explain the actual filter conditions rather than
claiming all debugfs output is always hidden.

**SAY:** “Look at the early return. The filter skips descriptor zero.”

**SOURCE:** [fd < 1 exclusion](/home/ponq/dev/lkmhunter/testbed/rootkits/Singularity/modules/hooks_write.c:603),
[ptrace changes the write argument](/home/ponq/dev/lkmhunter/utils/debugfs_output.c:51).

```bash
/root/mshp-debugfs-output debugfs -R 'ls -lp /root/workshop01' "$DISK_DEVICE" | cat
```

**EXPECT:** previously filtered entry is visible in the same listing. Confirm
this exact pipeline with the prepared sample before presenting.

**SAY:** “Zero means stdin by convention. We gave fd 0 a writable destination,
then used ptrace to change the descriptor argument of stdout writes. The
rootkit's assumption about that number lets this output through.”

Full comparison, scoped to the demo directory:

```bash
python3 /opt/lkmhunter/debugfs_hunt.py "$DISK_DEVICE" / \
    --directory /root/workshop01 --bypass-output-filter
```

**EXPECT:** missing VFS entries reported from raw disk enumeration. The scanner
protects both the child's output and its own report. It builds its output helper
when invoked; prepare the compiler before infection.

## 35–38 · Explain the helper; recover the callback owner **[S]**

**SAY:** “Our helper was loaded before this sample. It exposes a memory interface
that avoids this sample's kcore path. It still runs inside the same compromised
kernel. Ftrace scanning separately reads tracefs.”

```bash
ls -l /proc/lkm/mem
lkmhunter scan ftrace --json > "$EVIDENCE/singularity-ftrace.json"
cat "$EVIDENCE/singularity-ftrace.json"
S_DISPATCHER=$(pick_address "$EVIDENCE/singularity-ftrace.json" ftrace)
if [[ -n "$S_DISPATCHER" ]]; then
    lkmhunter module find "$S_DISPATCHER" --backend lkm_mem
    lkmhunter module dump "$S_DISPATCHER" --backend lkm_mem --out-dir "$EVIDENCE/singularity-memory"
fi
```

**EXPECT:** complete usable ftrace result, numeric callback, recovered owner,
and manifest with coverage. Erased names or damaged list pointers need not
prevent owner recovery. Do not insist on a printable `singularity` name.

**Rehearsal gate:** output filtering, multiple dispatchers, or tracefs filtering
can prevent this exact block from selecting an address. The selector stops on
partial or ambiguous results. `lkm_mem` does not repair tracefs. If this build
requires another input/output workaround, capture it before presenting; until
then use a labelled saved scan for this last step, not an invented live result.

**SOURCE:** [memory helper](/home/ponq/dev/lkmhunter/modules/src/lkm_mem.c:1),
[bounded owner recovery](/home/ponq/dev/lkmhunter/lkmhunter/scanners.py:250),
[read-only GDB bridge limitations](/home/ponq/dev/lkmhunter/docs/gdb-hunting.md:1).

Do not attempt normal unload: this sample's documented cleanup is a restart.
After the session, power off and restore the clean snapshot for every pane.

## 38–40 · Close

Back to the deck: **“Better than detecting: don't let it load”**, about 38:00.

**SAY:** “All three samples today were unsigned modules. With
`module.sig_enforce=1`, or lockdown, none of them loads: `insmod` fails with
‘Key was rejected by service’. Detection tells you it happened. Prevention
means it didn't.”

Keep the caveats short: signed does not mean harmless, so protect the signing
key; eBPF and kernel exploits do not need a `.ko`. Lockdown's confidentiality
mode also closes `/proc/kcore`, the view this talk relied on.

Then the final remarks, **“Found it. Removed it. Clean?”**, about 39:00:

**SAY:** “So, we're done. A few final remarks. Say you found the module, you
unloaded it, you even wrote the original bytes back. Are you good? Well… no.
That code ran in the kernel with full privileges. It could have changed
anything else: another hook, a file on disk, the initramfs, credentials. And
every check you run after that still asks the same kernel. So don't fight it on
a compromised box. Collect your evidence, reimage from known-good media, rotate
the credentials.”

**SAY:** “And the same goes the other way. ‘Nothing found’ needs a second
sentence: what did you inspect, and what could you not see? Diamorphine changed
a path we could compare. KoviD left that path alone. Singularity filtered what
we saw. A result only means something when you know the path that produced it.”

Keep it light, the pause after “Are you good?” is the joke. lkmhunter's
“sometimes disarm” is for analysis and containment, not for calling a machine
clean.

Then **Thank you / Questions?**, about 39:30. Leave it up during Q&A; the backup
slides follow it.

## Backup slide: unlinking is not unloading

Outside the timed path; use only if the audience asks how a module hides from
`lsmod`.

Sketch a module list before and after an entry is unlinked. The code and data
can remain allocated, and callbacks can still point into that memory.

**Say:** “Enumeration follows an index or a set of registered objects. Removing
an object from that view is different from unloading it.”

Introduce DKOM as direct kernel object manipulation, after explaining the idea.
Explain that `/proc/modules` and `/sys/module` represent different views.
Diamorphine leaves a useful sysfs clue; KoviD removes both normal views. A difference between those views alone is not a
universal rootkit test.

**SOURCE:** [Diamorphine module_hide](/home/ponq/dev/lkmhunter/testbed/rootkits/Diamorphine/diamorphine.c:321). Show it briefly. Focus on what
view it changes; skip implementation details that do not help the investigation.

**Transition:** “Hidden code is still in memory, at an address we can follow.
Do we find it?” Back to the timed path.


---

## Overflow — KoviD credential recovery experiment

This is the remaining research task, not a paste-ready stage sequence.
Use the timed path's known credential until this extraction has been rehearsed.

**SAY:** “Encryption at rest in kernel memory does not help much if the key and
ciphertext remain recoverable from that same memory.”

1. Preserve the exact unstripped module ELF and runtime addresses of its sections.
2. Locate `kv_crypto_engine_init`'s static `key` and `kvmgc_unhidekey` using that
   build. Private module symbols require correct section relocation; matching
   kernel symbols alone do not provide them.
3. Read the 32-byte AES key. Follow `kvmgc_unhidekey` to its object, then export
   its 16-byte IV, ciphertext pointer, length, and ciphertext through `kcore`.
4. Decrypt offline with AES-256-CBC; interpret the first eight plaintext bytes
   as the little-endian integer compared by `_crypto_cb`. Do not assume text
   encoding or PKCS padding; inspect the source's full encrypted block.
5. Compare with the known lab credential, then use the recovered value for the
   existing unhide command. Never claim the known value was extracted.

**SOURCE:** [crypto object layout](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/crypto.h:6),
[key initialization](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/crypto.c:18),
[decrypt and restore encrypted buffer](/home/ponq/dev/lkmhunter/testbed/rootkits/KoviD/src/crypto.c:135).

A module-region dump can omit the heap objects reached by those pointers.
The read-only GDB bridge cannot call `kv_decrypt` or break at its callback.

lkmhunter scan ftrace

lkmhunter recover kovid --module-elf /root/workshop01/dupa.ko --dispatcher 0xffffffffc0bf20a0 --backend kcore

python3 - <<'PY'
import os
fd = os.open('.', os.O_RDONLY | os.O_DIRECTORY)
try:
    try:
        os.unlink('7fa8964a16afd00f', dir_fd=fd)
    except FileNotFoundError:
        print('ENOENT man.')
finally:
    os.close(fd)
PY


rm -f -- 46936b8b26eeff04
printf 'unhide-lkm=1978101720260042\n' > /proc/mshpctl
grep '^kovid ' /proc/modules



## Rehearsal checklist — remove blockers before presenting

- Time the three panes and ten-minute introduction.
- Confirm each kernel/build pair and complete clean scans.
- Confirm selective Diamorphine repair followed by its actual exit cleanup.
- Confirm KoviD control timeout, file hiding, kcore export, and known-key unload.
- Confirm Singularity's exact pipe filtering, fd=0 comparison, helper access,
  numeric ftrace callback, and full owner recovery.
- Save labelled transcripts; replace this guide's conditional expectations with
  the captured output from the exact presentation states.

Historical evidence: [validation log](/home/ponq/dev/lkmhunter/testbed/VALIDATION.md:1).
The older [KoviD-only rehearsal guide](demo/README.md) has background notes;
this file is the three-case presenter flow.
