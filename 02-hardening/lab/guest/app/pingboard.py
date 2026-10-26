#!/usr/bin/env python3
"""pingboard — a tiny "fleet diagnostics" web service.

                    !!!  DELIBERATELY VULNERABLE LAB TARGET  !!!

This app exists to be exploited on stage and then contained. It takes a
caller-supplied string and feeds it straight into a shell. That is a textbook
command-injection / "RCE via command ingest" bug (CWE-78). Do NOT copy this
pattern, and do NOT run this service anywhere but the disposable lab VM.

Endpoints
  GET  /                      interactive dashboard, shows the uid it runs as
  GET  /api/ping?host=HOST    "reachability check": runs  ping -c1 -W1 <HOST>
                              via the shell  -> inject with  ?host=1.1.1.1;id
  POST /api/ingest   body     "log ingest": appends the body to a log file via
                              the shell       -> inject with a ; in the body

Stdlib only, so the lab's first boot needs no pip. The point of the talk is not
to fix this code (you should: use a list argv and no shell) but to make the bug
boring — to shrink what a successful injection can reach.
"""
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PORT = int(os.environ.get("PINGBOARD_PORT", "8080"))
LOG_DIR = os.environ.get("PINGBOARD_LOG_DIR", "/var/log/pingboard")
LOG_FILE = os.path.join(LOG_DIR, "ingest.log")


PAGE = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pingboard · MSHP</title>
<style>
:root{color-scheme:dark;--bg:#101214;--panel:#191c1f;--line:#34383c;--muted:#969da5;--lime:#d5ff5f;--pink:#fa91c0}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:#f5f5ed;font:15px/1.5 system-ui,sans-serif}button,input,textarea{font:inherit}button{cursor:pointer}a{color:inherit}header{border-bottom:1px solid var(--line)}.bar{max-width:1280px;margin:auto;padding:22px 40px;display:flex;align-items:center;gap:14px}.logo{background:var(--lime);color:var(--bg);font-size:21px;font-weight:950;padding:2px 9px;transform:rotate(-4deg);letter-spacing:-1px}.brand{font-weight:750;font-size:18px;letter-spacing:-.6px}.divider{height:22px;width:1px;background:var(--line);margin:0 8px}.micro,.tag,.eyebrow,label,.terminal-head,footer{font:11px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace;letter-spacing:1px}.micro{color:var(--muted)}.online{margin-left:auto;display:flex;gap:9px;align-items:center}.dot{width:7px;height:7px;border-radius:50%;background:var(--lime);box-shadow:0 0 14px #d5ff5f55}main{max-width:1280px;margin:auto;padding:48px 40px 24px}.hero{display:grid;grid-template-columns:1.3fr 1fr;align-items:center;gap:40px;margin-bottom:36px}.eyebrow{color:var(--lime)}h1{font-size:clamp(44px,6.2vw,80px);line-height:1.02;letter-spacing:-5px;margin:19px 0 20px;font-weight:850}h1 span{color:var(--lime)}.intro{color:var(--muted);max-width:440px;font-size:16px}.art{position:relative;height:245px;display:grid;place-items:center;overflow:hidden;background-image:radial-gradient(#43494c 1px,transparent 1px);background-size:18px 18px;mask-image:linear-gradient(90deg,transparent,#000 15%,#000 85%,transparent)}.orbit{position:absolute;width:210px;height:210px;border:1px solid #d5ff5f44;border-radius:50%}.orbit:before,.orbit:after{content:'';position:absolute;border:1px solid #d5ff5f33;border-radius:50%;inset:25px}.orbit:after{inset:-26px}.mascot{position:relative;width:144px;height:116px;border:3px solid var(--lime);border-radius:29px;background:#20291b;box-shadow:9px 9px 0 #080a09;transform:rotate(-9deg);display:flex;justify-content:center;align-items:center;gap:26px}.mascot:before{content:'';position:absolute;width:3px;height:32px;background:var(--lime);top:-34px;left:70px}.mascot:after{content:'';position:absolute;width:13px;height:13px;border-radius:50%;background:var(--pink);top:-43px;left:65px}.eye{width:13px;height:25px;background:var(--lime);border-radius:6px}.smile{position:absolute;bottom:17px;width:24px;height:12px;border-bottom:3px solid var(--lime);border-radius:50%}.sticker{position:absolute;right:7%;bottom:22px;background:var(--pink);color:#171318;transform:rotate(9deg);padding:7px 12px;font:700 12px ui-monospace,monospace;border:2px solid #101214}.cards{display:grid;grid-template-columns:1fr 1fr;gap:20px}.card{border:1px solid var(--line);background:var(--panel);border-radius:14px;padding:27px}.card-top{display:flex;align-items:center;gap:13px}.icon{width:40px;height:40px;border:1px solid #d5ff5f55;border-radius:10px;display:grid;place-items:center;color:var(--lime);font:24px monospace}.pink{color:var(--pink);border-color:#fa91c055}h2{font-size:21px;letter-spacing:-.7px;margin:0}.tag{margin-left:auto;color:var(--muted);font-size:10px;border:1px solid var(--line);border-radius:5px;padding:3px 7px}.description{margin:15px 0 23px;color:var(--muted);font-size:14px}label{display:block;margin-bottom:9px;color:#d0d4d6}input,textarea{display:block;width:100%;border:1px solid #454b50;border-radius:7px;background:#101214;color:#f5f5ed;padding:13px 14px;font:14px/1.5 ui-monospace,monospace;outline:none}input:focus,textarea:focus{border-color:var(--lime);box-shadow:0 0 0 3px #d5ff5f15}textarea{height:50px;min-height:50px;resize:vertical}button:focus-visible{outline:2px solid #fff;outline-offset:4px}.presets{display:flex;gap:7px;flex-wrap:wrap;min-height:37px;align-items:center;margin:9px 0 15px}.preset{background:transparent;color:var(--muted);border:1px solid var(--line);border-radius:5px;font:11px ui-monospace,monospace;padding:5px 8px}.preset:hover{color:var(--lime);border-color:var(--lime)}.hint{font:11px ui-monospace,monospace;color:var(--muted);margin:9px 0 15px;min-height:37px;display:flex;align-items:center}.submit{width:100%;padding:12px 16px;background:var(--lime);border:0;border-radius:7px;font-weight:750;display:flex;justify-content:space-between;align-items:center;color:#171b11}.submit.secondary{background:#fa91c0;color:#26131e}.submit:hover{filter:brightness(1.08)}.submit:disabled{opacity:.6;cursor:wait}.terminal{margin-top:22px;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:#0b0d0f}.terminal-head{padding:13px 19px;background:#202326;display:flex;gap:8px;align-items:center;color:#c5c9cd}.lamp{width:8px;height:8px;background:#50565b;border-radius:50%}.terminal-title{margin-left:9px}.status{margin-left:auto;color:var(--lime);font-size:10px}.clear{background:none;border:0;color:var(--muted);font:11px ui-monospace,monospace;margin-left:14px;padding:4px}.clear:hover{color:white}pre{margin:0;padding:22px;font:13px/1.75 ui-monospace,SFMono-Regular,Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;min-height:150px;max-height:380px;overflow:auto;color:#c4d0bf}.lab-note{display:flex;align-items:center;gap:12px;color:var(--muted);font-size:12px;padding:21px 0}.lab-note strong{color:var(--pink);font:11px ui-monospace,monospace;border:1px solid #fa91c044;padding:3px 7px;border-radius:4px;white-space:nowrap}footer{border-top:1px solid var(--line);padding:19px 0;color:var(--muted);display:flex;justify-content:space-between;gap:15px;font-size:10px}footer span:last-child{color:var(--lime)}@media(max-width:700px){.bar{padding:19px 20px}.bar>.micro,.divider{display:none}main{padding:34px 20px 20px}.hero{grid-template-columns:1fr;gap:0;margin-bottom:26px}h1{letter-spacing:-2.5px}.art{height:190px;margin-top:15px}.mascot{scale:.8}.orbit{scale:.8}.cards{grid-template-columns:1fr}.card{padding:21px}.lab-note{align-items:flex-start}footer{flex-direction:column;gap:5px}.online{font-size:10px}}@media(prefers-reduced-motion:no-preference){.mascot{animation:bob 5s ease-in-out infinite}@keyframes bob{50%{transform:translateY(-9px) rotate(-5deg)}}}
</style>
</head>
<body>
<header><div class="bar"><span class="logo">MSHP</span><span class="divider"></span><span class="brand">pingboard<span style="color:var(--lime)">_</span></span><span class="micro">FLEET DIAGNOSTICS</span><span class="online micro"><span class="dot"></span>SERVICE ONLINE</span></div></header>
<main>
<section class="hero"><div><div class="eyebrow">SMALL PACKETS. BIG ENERGY. ↗</div><h1>You ping.<br><span>We pong.</span></h1><p class="intro">A little network curiosity goes a long way.<br>Check a host, drop a log, see what comes back.</p></div><div class="art" aria-hidden="true"><div class="orbit"></div><div class="mascot"><i class="eye"></i><i class="eye"></i><i class="smile"></i></div><div class="sticker">100% packet-powered ✦</div></div></section>
<div class="cards">
<section class="card"><div class="card-top"><span class="icon" aria-hidden="true">⌁</span><h2>Ping a host</h2><span class="tag">01 / CONNECT</span></div><p class="description">Anybody out there? Send a packet and find out.</p><form id="ping-form"><label for="host">HOST / IP ADDRESS</label><input id="host" name="host" value="127.0.0.1" placeholder="e.g. 127.0.0.1" required autocomplete="off" spellcheck="false"><div class="presets"><span class="micro">TRY</span><button type="button" class="preset" data-host="127.0.0.1">localhost</button><button type="button" class="preset" data-host="1.1.1.1">1.1.1.1</button><button type="button" class="preset" data-host="8.8.8.8">8.8.8.8</button></div><button class="submit" type="submit"><span>Send ping</span><span aria-hidden="true">↗</span></button></form></section>
<section class="card"><div class="card-top"><span class="icon pink" aria-hidden="true">≡</span><h2>Drop a log</h2><span class="tag">02 / INGEST</span></div><p class="description">Something to report? Leave it in the captain’s log.</p><form id="ingest-form"><label for="message">LOG MESSAGE</label><textarea id="message" name="message" required placeholder="All systems go. Probably." spellcheck="false"></textarea><div class="hint">↳ Sent to the fleet’s ingest log.</div><button class="submit secondary" type="submit"><span>Send log</span><span aria-hidden="true">↗</span></button></form></section>
</div>
<section class="terminal" aria-label="Command results"><div class="terminal-head"><span class="lamp"></span><span class="lamp"></span><span class="lamp"></span><span class="terminal-title">LIVE OUTPUT</span><span class="status" id="status" role="status">READY</span><button type="button" class="clear" id="clear">Clear</button></div><pre id="output" tabindex="0">› Pingboard is ready. Your move.

  Send a ping or drop a log to see the response here.</pre></section>
<div class="lab-note"><strong>LAB MODE</strong><span>Deliberately vulnerable. Built for the MSHP hardening lab. Keep it in your disposable VM.</span></div>
<footer><span>MSHP / PINGBOARD v0.1 · UID __UID__ / GID __GID__</span><span>HACK. LEARN. HARDEN. REPEAT. ↗</span></footer>
</main>
<script>
const output=document.querySelector('#output'), status=document.querySelector('#status');
let active=0;
for(const button of document.querySelectorAll('[data-host]'))button.addEventListener('click',()=>{document.querySelector('#host').value=button.dataset.host;document.querySelector('#host').focus()});
document.querySelector('#clear').addEventListener('click',()=>{output.textContent='› Output cleared. Ready for another round.';if(!active)status.textContent='READY'});
async function send(event,kind){event.preventDefault();const form=event.currentTarget,button=form.querySelector('[type=submit]');button.disabled=true;active++;status.textContent='RUNNING…';output.textContent=kind==='ping'?'› Sending packet…':'› Sending log…';try{const response=await fetch(kind==='ping'?'/api/ping?host='+encodeURIComponent(form.elements.host.value):'/api/ingest',kind==='ping'?{}:{method:'POST',headers:{'Content-Type':'text/plain;charset=UTF-8'},body:form.elements.message.value});if(!response.ok)throw new Error('HTTP '+response.status+': '+await response.text());const result=await response.json();output.textContent='$ '+result.cmd+'\n\n'+(result.output||(result.exit===0?'Log received. No output returned.':'Command returned no output.'))+'\n[exit '+result.exit+']';status.textContent=result.exit===0?'COMPLETE':'EXIT '+result.exit}catch(error){output.textContent='› Request failed: '+error.message;status.textContent='ERROR'}finally{button.disabled=false;active--;if(active)status.textContent='RUNNING…'}}
document.querySelector('#ping-form').addEventListener('submit',event=>send(event,'ping'));
document.querySelector('#ingest-form').addEventListener('submit',event=>send(event,'ingest'));
</script>
</body></html>'''

def run_shell(cmd: str) -> tuple[int, str]:
    """Run a command line through /bin/sh. This is the vulnerability."""
    proc = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, timeout=15
    )
    return proc.returncode, (proc.stdout + proc.stderr)


class Handler(BaseHTTPRequestHandler):
    server_version = "pingboard/0.1"

    def _send(self, code: int, body: str, ctype: str = "text/plain"):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/":
            self._send(200,
                PAGE.replace("__UID__", str(os.getuid())).replace("__GID__", str(os.getgid())),
                "text/html; charset=utf-8")
            return
        if url.path == "/api/ping":
            host = parse_qs(url.query).get("host", [""])[0]
            if not host:
                self._send(400, "missing host\n")
                return
            # VULNERABLE: caller input concatenated into a shell command line.
            cmd = f"ping -c1 -W1 {host}"
            rc, out = run_shell(cmd)
            self._send(200, json.dumps(
                {"cmd": cmd, "exit": rc, "output": out}, indent=2) + "\n",
                "application/json")
            return
        self._send(404, "not found\n")

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == "/api/ingest":
            length = int(self.headers.get("Content-Length", "0") or "0")
            line = self.rfile.read(length).decode("utf-8", "replace").strip()
            os.makedirs(LOG_DIR, exist_ok=True)
            # VULNERABLE: caller input concatenated into a shell command line.
            cmd = f"echo {line} >> {LOG_FILE}"
            rc, out = run_shell(cmd)
            self._send(200, json.dumps(
                {"cmd": cmd, "exit": rc, "output": out}, indent=2) + "\n",
                "application/json")
            return
        self._send(404, "not found\n")

    def log_message(self, fmt, *args):  # quieter journal
        pass


def main():
    os.makedirs(LOG_DIR, exist_ok=True)
    print(f"pingboard listening on :{PORT} as uid={os.getuid()}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
