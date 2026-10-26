# Mega Securak Hacking Party

Two English Marp talks. Each allows **40 minutes including demos, plus 5 minutes of questions or overrun**. Speaker notes contain timing, technical explanations and fallback choices; slides carry the audience narrative.

- [Fresh Linux, Dirty Internet](02-hardening/slides.md): take one misconfigured server through access control, network exposure and service confinement. Repeat the application exploit probes after each control to compare its reach.
- [What if the kernel lies?](01-rootkits/slides.md): investigate a hidden module through ftrace, recover its owner with LKMHunter, and inspect the evidence with GDB.

## Build and present

Requires Node.js/npm and GNU Make. PDF and PPTX export also need Chrome/Chromium. Python is only needed for the optional hardening VM lab; no Python packages or `.venv` are needed for the decks.

```bash
make install             # npm ci, locked Marp version
make                     # HTML, PDF and PPTX decks
make html
make pdf
make pptx                # PowerPoint (slides as images, speaker notes kept)
make preview-hardening   # shared Marp server: select the relevant slides.md
make preview-rootkits    # same server; either target serves both decks
make clean               # remove generated build/ only
```

Artifacts: `build/01-rootkits/{index.html,slides.pdf,slides.pptx}` and `build/02-hardening/{index.html,slides.pdf,slides.pptx}`. Share each HTML deck's entire folder including assets. PDFs and PPTX embed the artwork; PPTX slides are rendered images (not editable text) with speaker notes attached. If Chrome cannot be found: `CHROME_PATH=/path/to/chrome make pdf pptx`.

## Demos

- [Hardening learning guide](02-hardening/README.md): one QEMU lab covering investigation, cleanup, application confinement and reset.
- [Rootkit rehearsal guide](01-rootkits/demo/README.md): compatible guest, current CLI, evidence interpretation, saved-run fallback.

`make` only builds slides. It does not provision machines, edit SSH, install firewall rules, or load modules. Lab configurations are drafts requiring a timed VM rehearsal; expected outcomes are not fabricated captured outputs.

## Existing template

The initial workspace already contained Marp CLI configuration and dependencies, the Cybertopia theme, an MSHP theme extension and LKMHunter artwork. There were no slide decks, Makefile or READMEs. The English revision replaces the initial Polish draft and gives the hardening demo a single repeatable application-level test.

Theme: [Cybertopia by noraj](https://github.com/noraj/cybertopia-marp), MIT. Local copy: `themes/cybertopia.css`; license: `themes/LICENSE.cybertopia`. `themes/mshp.css` contains presentation-specific styling. No external CSS or downloaded fonts are required when presenting built slides.
