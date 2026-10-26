# Fresh Linux, Dirty Internet — hardening learning guide

[Slides](slides.md) · [Setup](#one-time-setup) · [Exercises](#working-through-the-lab) · [Module reference](#module-reference) · [Reset](#resetting-the-lab)

Work through one cumulative QEMU lab: inspect an inherited server, verify its
weaknesses, remove planted backdoors, and constrain its vulnerable application.
Run the checks again after each change to connect the control to its effect.
Commands and output descriptions explain what to investigate; actual results
must be verified in your guest.

## Scenario

The self-contained QEMU VM boots an
Ubuntu 26.10 (`stonking`, matching the lkmhunter testbed) box that is **already running apps and already compromised**: it has
a pile of unnecessary packages, a web service with a real command-injection RCE
running as **root**, and a scattering of backdoors someone left behind (rogue
accounts, a root-target su PAM authentication bypass, sudo traps, a SUID-root shell, a pkexec/polkit hole, persistence, and
two network backdoors — one obvious, one covert). You walk in, find the mess,
clean it, and then limit what an attacker can reach through the app.
The injection remains a bug that must be fixed.

The exercises have two parts:

- **Part 1 — the inherited mess.** Triage an unknown box and remove what should
  not be there (accounts, sudo, SUID/caps, pkexec, persistence, stray listeners),
  then lock the front door (SSH + fail2ban) and the kernel/host surface
  (sysctl + mounts).
- **Part 2 — the app runtime.** The app *itself* is still exploitable. Gain
  visibility (auditd + eBPF), then shrink the blast radius (packages, nftables
  egress, AppArmor) and finally cage it in a least-privilege container.

The glue: cleaning the inherited backdoors does nothing about the app's own RCE —
so Part 2 makes the app less able to reach host resources after exploitation.

> **Safety.** Everything runs inside a throwaway QEMU guest reachable only through
> host-local port forwards (`localhost:2223` ssh, `localhost:8080` app). The
> service, planted backdoors and exploit are intentionally dangerous. Egress is
> initially open for provisioning and the before/after probes; host-local port
> forwards do not block outbound traffic. Never run the payload outside this VM. `./snapshot.sh restore clean` restores the saved VM state.

## Host prerequisites

The host needs: `qemu-system-x86_64`, `qemu-img`, KVM, `socat`, and one of
`cloud-localds`, `xorriso` or `genisoimage` to build the cloud-init seed. To install
`cloud-localds`:
`sudo apt-get install cloud-image-utils`.

## One-time setup

```bash
cd 02-hardening/lab
./setup.sh                            # build disk + seed (reuses a local Ubuntu
                                      # base image if one exists; payload embedded)
./run.sh --daemon                     # boot in background; console -> console.log
./ssh.sh 'cloud-init status --wait'   # wait out first-boot provisioning (~4-6 min)
curl http://localhost:8080/           # the vulnerable app answers on the host
```

Continue with [baseline verification](#verify-and-save-the-baseline) to verify and save the baseline.

## Ubuntu release and rollback

The default image is Ubuntu 26.10 (`stonking`), matching the local lkmhunter
testbed. `setup.sh` reuses its pristine base image when available; each release
has its own working disk and snapshots. Snapshots do not transfer between releases.

To prepare another release, stop the VM first, then run `setup.sh` and `run.sh`
with the same `CLOUD_RELEASE` override. The cloud-init seed is shared between
releases, so regenerate it with `setup.sh` when switching:

```bash
./stop.sh
CLOUD_RELEASE=noble ./setup.sh
CLOUD_RELEASE=noble ./run.sh --daemon
```

This preserves and boots an existing Noble disk without resetting it.
The optional Diamorphine binary must match the running kernel; see the optional rootkit preparation below.

## Everyday commands

| Command | What it does |
|---|---|
| `./run.sh --daemon` | Boot in background, console to `console.log`. |
| `./run.sh` | Boot in foreground (`Ctrl-a x` quits, `Ctrl-a c` = QEMU monitor). |
| `./run.sh --share` | Also mount `guest/` over 9p for live editing (disables snapshots). |
| `./ssh.sh ['cmd']` | Shell in as `hunter` (sudo). `GUEST_USER=root ./ssh.sh` for root. |
| `./snapshot.sh save\|restore\|list [name]` | Live VM snapshots; waits for QEMU to finish. |
| `./stop.sh` | Graceful shutdown (`--force` / `--status`). |
| `./reset.sh` | Roll the disk back to pristine (VM off; re-provisions on next boot). |

The payload is embedded in the seed and extracted to `/opt/pingboard` at first
boot, so the VM is self-contained. `guest/badseed/install.sh` is the **answer
key** — it is literally what made the box dirty.

## Working through the lab

Host helper commands run from `02-hardening/lab`; `cd 02-hardening/lab`
assumes you start at the repository root. Unless marked **host**, exercise
commands below run **inside the guest**. Open two SSH panes from the host:

- **[admin]** `GUEST_USER=root ./ssh.sh` (or `./ssh.sh` + `sudo`)
- **[attacker]** `./ssh.sh`

Complete the exercises in order on the same VM. Most groups have a helper under `/opt/pingboard/harden/`; the module reference
below lists them. The package step uses `30-packages.sh` and Docker uses `60-docker/up.sh`.

## Verify and save the baseline

```bash
cd 02-hardening/lab
./run.sh --daemon
./ssh.sh 'cloud-init status --wait'     # wait for "status: done"
curl -s http://localhost:8080/          # app answers
./verify-baseline.sh                    # verify the current startup hook and fixtures
./snapshot.sh save clean                # freeze the pristine dirty box
```
Open both panes. **Reset the lab at any time:** `./snapshot.sh restore clean`.

## Optional exercise: hidden processes

The two planted backdoors can keep running while Diamorphine hides their PIDs
from `/proc` enumeration. This hides them from `ps`; it does **not** hide their
shared systemd unit, TCP/raw sockets, or every way of inspecting a known PID.
Use the [supplied source](lab/guest/badseed/Diamorphine/diamorphine.c), not a different
sample with different signal numbers. This optional exercise connects process visibility to the rootkit material in
workshop 01. Skip it to work with ordinary process listings.

**[guest/admin]** The supplied `.ko` targets an older kernel and must not be
assumed compatible with the Ubuntu 26.10 guest. Check:

```bash
uname -r
modinfo -F vermagic /diamorphine/diamorphine.ko
```

If they differ, rebuild **inside the guest before loading the module**:

```bash
cd /opt/pingboard/badseed/Diamorphine
make clean
make
sudo install -m0644 diamorphine.ko /diamorphine/diamorphine.ko
```

Headers for the running kernel must already be installed. Do not force-load a
mismatched module. Existing guests need the updated lab payload and both new
unit definitions installed; changing the host payload does not update an
already-provisioned guest. Use a freshly provisioned VM for this startup layout.

```bash
sudo systemctl restart app-data-start.service
sudo python3 /opt/pingboard/badseed/process-visibility.py hide
```

The controller should report `hidden=True` for both helper processes. The helper loads the prepared
module if needed, reads helper PIDs from root-only `/run/pingboard/*.pid` files, validates the expected script,
and uses signal 31 only when the supplied visibility flag needs changing.
Repeated `hide` does not reveal an already-hidden PID. Restarting the startup unit
creates a new PID; reapply `hide` afterward.

**[HOST]** Save this state separately from the module-free `clean` state:

```bash
./snapshot.sh save hidden-backdoors
```

Restore `hidden-backdoors` to repeat this exercise; restore `clean` to return to
the module-free baseline. Do not claim a successfully unloaded rootkit proves a
trusted machine; rebuilding from a known-good state remains the incident response.

## Recon — what did we inherit?   **[admin]**

Inventory accounts, privilege grants, persistence and sockets before changing
the server. TCP listeners alone do not reveal every network backdoor.

```bash
# accounts that can become root
awk -F: '($3==0){print $1}' /etc/passwd
getent group sudo docker
```
Identify the two UID-0 users (`root`, `svc-deploy`) and the membership of
`webops` in both `sudo` and `docker`. Each provides a path to host privileges.

```bash
# sudo rules dropped in
sudo cat /etc/sudoers.d/90-webops
```
The rule `webops ALL=(ALL) NOPASSWD: /usr/bin/less` lets `webops` run the pager
as root without a password. Its file access and shell features make this dangerous.

```bash
# SUID-root binaries outside the usual set
find / -xdev -perm -4000 -type f 2>/dev/null | grep -vE '^/usr/(bin|sbin|lib)'
# file capabilities on interpreters
getcap -r / 2>/dev/null
```
Look for the SUID-root `/usr/local/bin/notes` and
`…/python3.<version> cap_setuid=ep`. The latter lets the interpreter change its UID.

```bash
# persistence + a pkexec rule
cat /etc/cron.d/backup
sudo cat /etc/polkit-1/rules.d/49-trusted.rules
sudo cat /root/.ssh/authorized_keys
```
Identify the root cron beacon, the polkit rule returning YES for group `webops`,
and the unknown `ATTACKER-DROPPED-KEY` in root's keys.

```bash
# the covert backdoor: NOTHING on a TCP port...
ss -lntup | grep 31337
# ...yet a daemon is holding a raw socket:
sudo ss --raw -p
ps -eo pid,user,comm,args | grep -i knock | grep -v grep
```
Without process hiding, there is no listener on 31337, but `knockd-helper.py` is
running with a raw socket. With process hiding enabled, `ps` omits both backdoor
processes even though sockets remain. Owner attribution in `ss -p` may also be
missing because it depends on process enumeration; the socket itself is not hidden.

### Compare hidden processes with other evidence **[admin]**

Compare the process listing with the startup unit, PID files and sockets.
A hidden process can keep running while disappearing from enumeration.

```bash
systemctl status app-data-start.service
sudo cat /run/pingboard/*-helper.pid
sudo python3 /opt/pingboard/badseed/process-visibility.py status
sudo ss -lntp 'sport = :4444'
sudo ss --raw -p
```

The oneshot remains active (exited) and its PID files identify the helpers; the helper confirms their hidden
flag; the telemetry listener and raw socket still exist. Direct known-PID reads
can work even when directory enumeration omits that PID.

Reveal the two processes without restarting them, then compare their PIDs.

```bash
sudo python3 /opt/pingboard/badseed/process-visibility.py reveal
ps -eo pid,user,comm,args | grep -E '[t]elemetry-helper.py|[k]nockd-helper.py'
```

Both reappear with the same PIDs. Continue with the attacks, then the
cleanup below. The module remains loaded until the explicit cleanup step.

Source: [PID hiding toggle](lab/guest/badseed/Diamorphine/diamorphine.c),
[signal definitions](lab/guest/badseed/Diamorphine/diamorphine.h),
[process visibility controller](lab/guest/badseed/process-visibility.py).

---

## Verify privilege escalation and remove backdoors

### Test the planted privilege grants   **[attacker]**
From the compromised low-priv user, this box hands out root four ways.

```bash
sudo -u webops -s          # become 'webops'; prompt changes
id                         # webops, not root (numeric UID may vary)
```
```bash
# 1) SUID-root shell
echo 'id; cat /root/flag.txt' | /usr/local/bin/notes
# 2) polkit/pkexec backdoor
pkexec id
# 3) cap_setuid on python
python3 -c 'import os,subprocess; os.setuid(0); subprocess.run(["id"])'
# 4) passwordless less (GTFOBins reads any file as root)
sudo -n less /root/flag.txt
exit                       # back to hunter
```
The first three routes execute with UID 0; `less` displays the flag
`MSHP{…}`. Press `q` to leave `less` if it opens a pager.

And the covert backdoor — nothing listening until a magic packet.
```bash
ss -lntup | grep 31337                               # silence
ping -c1 -W1 -p 4d5348502d4b4e4f434b 127.0.0.1       # payload "MSHP-KNOCK"
ss -lntup | grep 31337                               # now :31337 is LISTENing
printf 'id\ncat /root/flag.txt\nexit\n' | nc 127.0.0.1 31337
```
After the ping, `:31337` appears and the shell runs as root + reads the flag.

### su PAM authentication bypass

Provisioning prepends this to `/etc/pam.d/su` and `/etc/pam.d/su-l`
when present. Some Ubuntu releases have an independent `su-l` stack:

```text
auth sufficient pam_succeed_if.so user = root # MSHP-SU-PAM-BYPASS
```

The condition tests the target account. An ordinary caller running `su -` can
become root without password verification; other targets retain normal auth.
Account/session checks still apply. This does not change SSH or shared
`common-auth`. Recon displays the rule; step `03-privesc` removes it.
Run `su -` as hunter, never `sudo su -`: root callers normally bypass passwords
via the legitimate `pam_rootok` rule. No password prompt is expected while the
bypass is present. On this cloud image root is password-locked, so after removal
ordinary-user `su -` is denied; sudo for the intended administrator still works.

Existing guests and saved snapshots do not receive source changes automatically.
Rebuild the seed with `./setup.sh`, then use the documented full reset/reprovision
flow and save a new dirty-state snapshot. Do not rerun all of badseed on a
partially hardened guest. Restore the snapshot to repeat the bypass exercise.

In the **hunter SSH pane**, without sudo:

```bash
id                         # hunter, not root
su -                       # no password prompt
id                         # uid=0(root)
exit                       # back to hunter
sudo head -n 8 /etc/pam.d/su
```

Root SSH login can be disabled and an ordinary user can still become
root. This sufficient PAM rule accepts the target username without checking a
password. The normal pam_rootok rule trusts an already-root caller; our planted
rule trusts a root target, even when the caller is unprivileged.

Keep a hunter key session with sudo available. Cleanup removes the marked rule;
repeat `su -` as hunter afterward: it requests authentication and fails (root is
password-locked in this cloud image). Do not use `sudo su -`, which starts as root
and would succeed normally. Press Ctrl-C if you only want to show the prompt.

### Clean it up   **[admin]**

**If using the hidden-process exercise, reveal before stopping the startup unit:**

```bash
sudo python3 /opt/pingboard/badseed/process-visibility.py reveal
# Signal 63 toggles MODULE visibility; only send it if the loaded module is hidden.
if test -d /sys/module/diamorphine; then
    if ! grep -q '^diamorphine ' /proc/modules; then
        sudo kill -63 1
    fi
    sudo rmmod diamorphine
fi
```

Confirm that both PIDs are visible and module unloading succeeds. If reveal or unload fails,
stop this cleanup sequence and restore the clean snapshot. Do not apply this
signal sequence without the prepared module. Continue below only after success.
Remove exactly what recon found.
```bash
# accounts
sudo userdel -f svc-deploy
sudo gpasswd -d webops sudo
sudo gpasswd -d webops docker
sudo sed -i '/ATTACKER-DROPPED-KEY/d' /root/.ssh/authorized_keys
```
```bash
# privilege-escalation backdoors
sudo sed -i '/# MSHP-SU-PAM-BYPASS$/d' /etc/pam.d/su /etc/pam.d/su-l
sudo rm /etc/sudoers.d/90-webops
sudo chmod u-s /usr/local/bin/notes
sudo setcap -r "$(readlink -f /usr/bin/python3)"
sudo rm /etc/polkit-1/rules.d/49-trusted.rules
```
```bash
# persistence + both backdoor listeners
sudo bash /opt/pingboard/harden/04-persistence/apply.sh
sudo bash /opt/pingboard/harden/05-services/apply.sh
```

Repeat the attacks to verify the cleanup.   **[attacker]**
```bash
sudo -u webops -s
echo 'id' | /usr/local/bin/notes ; pkexec id ; python3 -c 'import os;os.setuid(0)'
sudo -n less /root/flag.txt ; exit
ping -c1 -W1 -p 4d5348502d4b4e4f434b 127.0.0.1 ; printf 'id\n' | nc -w2 127.0.0.1 31337
```
Every route now fails (not SUID / pkexec demands auth / `Operation not
permitted` / no `less`); knock → `Connection refused`.

---

## Lock the front door + the host surface   **[admin]**

Make the only intended way in explicit. Keep the console and an existing
hunter key session with working sudo open. Root SSH will be disabled; use hunter
with sudo for new admin sessions afterward.
```bash
cat /opt/pingboard/harden/06-ssh/mshp-sshd.conf
sudo cp /opt/pingboard/harden/06-ssh/mshp-sshd.conf /etc/ssh/sshd_config.d/00-mshp.conf
sudo /usr/sbin/sshd -t
# Match the real user and QEMU NAT source address:
sudo /usr/sbin/sshd -T -C user=hunter,host=localhost,addr=10.0.2.2 | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) '
sudo systemctl reload ssh
```
Confirm `permitrootlogin no`, `passwordauthentication no`,
`kbdinteractiveauthentication no`, and `pubkeyauthentication yes`. Check Include
placement, earlier drop-ins and Match blocks if the effective values differ;
SSH usually uses the first obtained value. Adapt this policy if using
keyboard-interactive MFA.

From the **host**, open a fresh `./ssh.sh` session and run `sudo -v`. Also try
`GUEST_USER=root ./ssh.sh`: it should reject authentication. Check the methods
advertised to an unauthenticated client:

```bash
ssh -vv -p 2223 -o PubkeyAuthentication=no -o PreferredAuthentications=none hunter@localhost
```

Look for the server's `Authentications that can continue` list: public key should
remain available, with password and keyboard-interactive absent. A failed login
alone does not prove the authentication policy. Use your configured SSH port if
it differs from 2223. Keep the original session until the new login and sudo work.

For rollback, use the existing session or console to remove only
`/etc/ssh/sshd_config.d/00-mshp.conf`, restore any prior version of that file,
run `sudo /usr/sbin/sshd -t`, and reload SSH. Brute-force throttling is a further
exercise below.

Harden the kernel/network knobs, and make scratch space unexecutable.
```bash
cat /opt/pingboard/harden/07-sysctl-mounts/99-mshp-hardening.conf
sysctl kernel.yama.ptrace_scope                       # before: 1
sudo cp /opt/pingboard/harden/07-sysctl-mounts/99-mshp-hardening.conf /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.d/99-mshp-hardening.conf
sysctl kernel.yama.ptrace_scope                       # after: 2
```
```bash
# make /tmp noexec and prove a dropped payload can't run
sudo mount -t tmpfs -o noexec,nosuid,nodev tmpfs /tmp
printf '#!/bin/sh\necho pwned\n' > /tmp/x.sh; chmod +x /tmp/x.sh; /tmp/x.sh || echo "blocked by noexec"
```
Confirm that `ptrace_scope` is now 2 and executing `/tmp/x.sh` fails with
`Permission denied`. The `noexec` mount blocks direct execution; it does not
prevent an interpreter from reading a script, for example `sh /tmp/x.sh`.

---

## The app itself is still a root RCE   **[attacker]**

We cleaned the inherited mess. The app we were handed is still exploitable —
it feeds our input straight into a shell.
```bash
# identity: the injection runs as whoever the app is (root)
curl -s 'http://127.0.0.1:8080/api/ping?host=127.0.0.1%3Bid'
# read root's secret and the service secret
curl -s 'http://127.0.0.1:8080/api/ping?host=127.0.0.1%3Bcat%20/root/flag.txt'
curl -s 'http://127.0.0.1:8080/api/ping?host=127.0.0.1%3Bcat%20/srv/pingboard/secret.env'
```
The responses should contain `uid=0(root)`, the flag, and the DB creds.

```bash
# the full blast radius (egress, persistence, toolbox) in one sweep:
bash /opt/pingboard/attack/pwn.sh
```
Use `EGRESS-OK`, `WROTE-CRON`, and the toolbox results as the baseline for
comparison after applying controls. Egress success depends on network availability.

---

## Record application activity   **[admin]**

Audit rules record sensitive file access, while the eBPF tracer records executed
commands. Repeating the exploit lets you correlate its actions with both logs.
```bash
cat /opt/pingboard/harden/10-auditd/mshp.rules
sudo cp /opt/pingboard/harden/10-auditd/mshp.rules /etc/audit/rules.d/mshp.rules
sudo systemctl enable --now auditd
sudo augenrules --load
```
```bash
sudo cp /opt/pingboard/harden/20-telemetry/mshp-execsnoop.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mshp-execsnoop.service
```
Run the exploit again, then look.   **[attacker]** `bash /opt/pingboard/attack/pwn.sh`
```bash
# [admin]
sudo ausearch -if /var/log/audit/audit.log -k secret -i | tail
sudo tail -n 20 /var/log/mshp/exec.log
```
Auditd shows `comm=cat … /root/flag.txt … key=secret`; the eBPF log
shows `caller=sh … -> /usr/bin/cat cat /root/flag.txt`.

---

## Restrict packages, network access and application permissions   **[admin]** (re-run `pwn.sh` after each)

Remove the optional packages used by the post-exploitation probes.
```bash
dpkg --get-selections | grep -c '\binstall$'
sudo bash /opt/pingboard/harden/30-packages.sh
dpkg --get-selections | grep -c '\binstall$'
```
Compare the package counts and repeat `pwn.sh`. Probe #6 should find fewer
post-exploitation tools; their removal does not fix the injection.

Apply a default-drop outbound policy to the host service. DNS and established
connections remain allowed; new arbitrary outbound connections are blocked.
```bash
cat /opt/pingboard/harden/40-nftables/mshp.nft
sudo nft -c -f /opt/pingboard/harden/40-nftables/mshp.nft
sudo bash /opt/pingboard/harden/40-nftables/apply.sh
sudo nft list table inet mshp
```
Repeat `pwn.sh`: probe #4 should report `EGRESS-BLOCKED`. Check that SSH and
the app remain reachable. These rules filter host traffic; Docker forwarding
and container egress need separate controls.

### Verify firewall enforcement separately from service removal

A stopped backdoor proves service cleanup, not packet filtering. In the guest,
start a temporary harmless listener on a port that the rules do not allow:

```bash
sudo systemd-run --unit=mshp-firewall-check --property=User=nobody /usr/bin/python3 -m http.server 9000 --bind 0.0.0.0 --directory /usr/share/doc
curl --fail http://127.0.0.1:9000/ >/dev/null
sudo nft list table inet mshp
```

The loopback request should work. QEMU only forwards SSH and the app by default,
so a failed host request to port 9000 would merely test the missing NAT forward.
Use the host-side `socat` tool to add a temporary loopback-only QEMU forward
to guest port 9000:

```bash
# Host, from 02-hardening/lab; the monitor socket is in images/ by default.
printf 'hostfwd_add tcp:127.0.0.1:9000-:9000\n' | socat - UNIX-CONNECT:images/monitor.sock
curl --max-time 3 http://127.0.0.1:9000/
```

Check that QEMU accepted the forwarding command. The request should time out;
inspect the guest's final input-drop counter before and after the request. Also
verify a new SSH login and a successful host request to port 8080. Remove the
listener and temporary forward when finished:

```bash
# Guest
sudo systemctl stop mshp-firewall-check.service
# Host
printf 'hostfwd_remove tcp:127.0.0.1:9000\n' | socat - UNIX-CONNECT:images/monitor.sock
```

If networking fails, use the guest console to run
`sudo nft delete table inet mshp`. This removes only the lab table, preserving
Docker's rules. These firewall rules are runtime configuration; production
needs a chosen persistence mechanism and a reboot test.

### Run the host service as a dedicated user

Before adding AppArmor, isolate Unix permissions from service namespace rules.
Create a service account and one deliberately writable configuration fixture:

```bash
sudo useradd --system --user-group --no-create-home --shell /usr/sbin/nologin pingboard
sudo install -d -o root -g root -m 0755 /srv/pingboard-lab
printf 'mode=lab\n' | sudo tee /srv/pingboard-lab/app.conf >/dev/null
sudo chown pingboard:pingboard /srv/pingboard-lab/app.conf
sudo chmod 0644 /srv/pingboard-lab/app.conf
sudo install -d /etc/systemd/system/pingboard.service.d
sudo tee /etc/systemd/system/pingboard.service.d/45-identity.conf >/dev/null <<'UNIT'
[Service]
User=pingboard
Group=pingboard
LogsDirectory=pingboard
StateDirectory=pingboard
# Keep only the capability required for ping's raw-socket fallback.
CapabilityBoundingSet=CAP_NET_RAW
AmbientCapabilities=CAP_NET_RAW
NoNewPrivileges=yes
UNIT
sudo systemctl daemon-reload
sudo systemctl restart pingboard
sudo journalctl -u pingboard -n 10 --no-pager
```

Run this account-creation step once per baseline. Keep application code and unit
files root-owned. `LogsDirectory` and `StateDirectory` provide service-owned
writable locations; the existing ingest log remains in `/var/log/pingboard`.
The ambient capability supports ping when a datagram ICMP socket is unavailable;
this capability is still authority the app retains.

Repeat the identity and root-secret requests from the RCE exercise. The injected
`id` should show `pingboard`, and reading `/root/flag.txt` should fail through Unix
permissions. Confirm the legitimate ping and log-ingest features still work:

```bash
curl --fail 'http://127.0.0.1:8080/api/ping?host=127.0.0.1'
curl --fail --data 'learning-guide-check' http://127.0.0.1:8080/api/ingest
curl --fail --get --data-urlencode 'host=127.0.0.1; printf "probe\n" >> /srv/pingboard-lab/app.conf' http://127.0.0.1:8080/api/ping
```

The configuration write should still succeed: its owner is the service user.
Read the JSON command output and exit status, not just the HTTP status.

### Add a read-only service filesystem

```bash
sudo tee /etc/systemd/system/pingboard.service.d/46-sandbox.conf >/dev/null <<'UNIT'
[Service]
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
UNIT
sudo systemctl daemon-reload
sudo systemctl restart pingboard
```

Repeat the exact configuration-write request: it should now fail with a
read-only-filesystem error. This comes from the service's mount namespace even
though Unix ownership still permits writing. Confirm that intended state and
log writes remain possible:

```bash
curl --fail --get --data-urlencode 'host=127.0.0.1; printf "state\n" >> /var/lib/pingboard/probe.txt' http://127.0.0.1:8080/api/ping
curl --fail --data 'sandbox-check' http://127.0.0.1:8080/api/ingest
curl --fail 'http://127.0.0.1:8080/api/ping?host=127.0.0.1'
```

`StateDirectory` and `LogsDirectory` provide writable exceptions to
`ProtectSystem=strict`. `PrivateTmp` gives the service private temporary storage;
API filesystems are not completely confined by `ProtectSystem`.
`NoNewPrivileges` prevents gaining privileges through exec, while the capability
bounding set restricts available capabilities. Neither fixes command injection.
Do not use a separate `sudo -u pingboard` process as proof of service namespace
restrictions: send the probes through the application itself.

Fix the underlying ownership mistake after observing the distinction:

```bash
sudo chown root:root /srv/pingboard-lab/app.conf
sudo chmod 0644 /srv/pingboard-lab/app.conf
```

To undo these two service steps, remove only `45-identity.conf` and
`46-sandbox.conf`, then daemon-reload and restart. That restores the unsafe root
service, so use it only for comparison in this disposable VM. Continue with
AppArmor while the identity and sandbox drop-ins remain installed.

### Apply mandatory application permissions

AppArmor adds restrictions beyond the dedicated UID and read-only mounts. It
also constrains root processes: the profile applies independently of Unix UID.
```bash
cat /opt/pingboard/harden/50-apparmor/mshp-pingboard
sudo apparmor_parser -r /opt/pingboard/harden/50-apparmor/mshp-pingboard
sudo mkdir -p /etc/systemd/system/pingboard.service.d
printf '[Service]\nAppArmorProfile=mshp-pingboard\n' | sudo tee /etc/systemd/system/pingboard.service.d/50-apparmor.conf
sudo systemctl daemon-reload && sudo systemctl restart pingboard
```
```bash
# [attacker] injection blocked, legit feature still works
curl -s 'http://127.0.0.1:8080/api/ping?host=127.0.0.1%3Bcat%20/root/flag.txt'
curl -s 'http://127.0.0.1:8080/api/ping?host=127.0.0.1'
# [admin] the denials
sudo journalctl -k --since '-2 min' | grep -i apparmor | tail
```
The injected `cat` should now fail at execution under AppArmor; earlier, it
could execute but Unix permissions denied the root-only file. Check the kernel
log for the actual AppArmor denial, rather than inferring its cause from the
HTTP response. The legitimate ping and ingest features should still work.
The extra `/srv/pingboard-lab` and `/var/lib/pingboard` probes above are outside
this teaching profile and are not expected to remain allowed after attaching it.

To roll back AppArmor, remove only `50-apparmor.conf`, daemon-reload and restart
the service, then unload the profile with
`sudo apparmor_parser -R /opt/pingboard/harden/50-apparmor/mshp-pingboard`.
Manual profile loading is not configured for boot persistence here.

---

## Run the application in a restricted container   **[admin]**

Run the application as UID 10001 with a read-only root filesystem, no Linux
capabilities, and explicit writable temporary paths. Inspect each Docker flag
and compare the same probes with their earlier results. The host service
drop-ins do not automatically apply to the container; Docker has its own
identity, mount and security settings.
```bash
cat /opt/pingboard/harden/60-docker/Dockerfile
sudo systemctl disable --now pingboard.service
sudo docker run -d --name pingboard -p 8080:8080 \
  --user 10001:10001 --read-only \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 128 --memory 256m \
  --tmpfs /tmp --tmpfs /var/log/pingboard \
  --restart unless-stopped mshp/pingboard:hardened
sudo docker ps
```
```bash
# [attacker] compare identity and secret access after confinement
curl -s http://127.0.0.1:8080/
curl -s 'http://127.0.0.1:8080/api/ping?host=127.0.0.1%3Bcat%20/root/flag.txt'
```
Confirm that the health response shows `uid=10001` and `/root/flag.txt` is inaccessible;
the injection runs as an unprivileged user in a read-only throwaway container.

---

## What the controls changed

The injection in `app/pingboard.py` remains unpatched. Fix it by validating the
destination and passing an argument list to the subprocess without a shell. These controls reduce *what a mistake can reach*: on
the inherited host and in its application. For each control, explain which operation it blocked, which operations remain
possible, and how you verified that the legitimate application still works.

---

## Further exercises

### fail2ban brute-force lockout — optional, read the caveat
Testing lockout requires a **separate client box / real client IP**. In this
single-VM lab, QEMU NAT makes every host connection look like the gateway
`10.0.2.2`, so a ban also **locks out your own admin SSH**. Inspect the jail without triggering a ban when using the shared NAT address.
```bash
# enable the jail
printf '[sshd]\nenabled = true\nmaxretry = 3\nbantime = 10m\n' | sudo tee /etc/fail2ban/jail.d/sshd.local
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```
If a test triggers a ban, use an existing guest session or the console to run
`sudo fail2ban-client set sshd unbanip 10.0.2.2`. A new SSH connection may already
be blocked. These host commands illustrate the test and recovery attempt:
```bash
# from the HOST:
for i in 1 2 3 4; do ssh -o StrictHostKeyChecking=no -p 2223 nosuchuser@localhost true 2>/dev/null; done
./ssh.sh 'sudo fail2ban-client status sshd'
./ssh.sh 'sudo fail2ban-client set sshd unbanip 10.0.2.2'   # recover before you lose the pane
```

### File integrity, remote logs and vulnerability scanning
```bash
sudo bash /opt/pingboard/harden/70-aide/apply.sh baseline   # ...attack... then: apply.sh check
sudo bash /opt/pingboard/harden/80-offhost-logs/apply.sh
sudo bash /opt/pingboard/harden/90-scan/apply.sh            # Trivy image + Lynis: contain != patch
```

### The answer key
[Provisioning source](lab/guest/badseed/install.sh) shows how each weakness was
planted. Compare it with your findings after completing the exercises.

## Module reference

| Step | Path | Teaches | Honest limit |
|---|---|---|---|
| recon | `01-recon/` | triage an unknown box; listening ≠ `ss -lntup` | read-only; finds what it knows to look for |
| accounts | `02-accounts/` | UID-0, root-equiv groups, stray keys | also need pwquality/faillock |
| privesc | `03-privesc/` | sudoers, SUID, file caps, pkexec/polkit | an admin can still re-add them |
| persistence | `04-persistence/` | remove cron; inspect rc.local/crontabs | rootkits can hide deeper |
| services | `05-services/` | startup hook, bind shell and raw-socket backdoor | a firewall is not service removal |
| ssh | `06-ssh/` | key-only/no-root + fail2ban | adapt for MFA; keys still get stolen |
| sysctl/mounts | `07-sysctl-mounts/` | kernel/net knobs, noexec scratch | remounts need fstab to persist |
| auditd | `10-auditd/` | tamper-ish command/secret record | local logs die with the host |
| telemetry | `20-telemetry/` | live eBPF exec stream (Falco/Tetragon class) | a tracer, not a control |
| packages | `30-packages.sh` | attack surface = installed code + tools | test before purging in prod |
| nftables | `40-nftables/` | default-drop egress, not just ingress | container egress is Docker's domain |
| systemd | `45-identity.conf`, `46-sandbox.conf` (created above) | dedicated UID, writable state, read-only service filesystem | retains CAP_NET_RAW; injection remains |
| apparmor | `50-apparmor/` | MAC constrains a process regardless of UID | teaching profile, not full policy |
| docker | `60-docker/` | least privilege by construction | still not fixing the bug/base image |
| aide | `70-aide/` | file-integrity baseline + diff | baseline must live off-host too |
| off-host logs | `80-offhost-logs/` | evidence the attacker can't erase | needs a real remote collector |
| scan | `90-scan/` | contain ≠ patch (Trivy/debsecan/Lynis) | scanners find items, not your risk |

## Resetting the lab

`clean` means the **untouched, deliberately vulnerable lab baseline**, not a
hardened production server. It includes the current application-data startup
hook and its two helper processes. Snapshots retain the payload version they
were saved with; source edits do not update existing snapshots.

After restoring, check readiness with:

```bash
./snapshot.sh restore clean
./verify-baseline.sh
```

The snapshot helper waits for QEMU to finish and reports missing snapshots or
monitor errors. Reconnect SSH after restoring; existing sessions may disconnect.

- `./snapshot.sh restore clean` — fastest, if you saved a `clean` snapshot.
- `./stop.sh && ./reset.sh` — full rollback; re-provisions on next boot.
- `./run.sh --snapshot` — ephemeral boot; disk writes discarded on shutdown.
