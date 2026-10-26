# What if the kernel lies?

[Presenter run-sheet](script.md) · [Slides](slides.md) · [Earlier KoviD rehearsal guide](demo/README.md)

The [presenter run-sheet](script.md) follows Diamorphine, KoviD, then Singularity, with commands, speaking cues, and local source links. The slides cover the foundations and kernel protections, including a KASLR explanation followed by a terminal measurement. After prep, present the investigations from the run-sheet; return to the deck for closing and questions.

Intermediate. Target: 40 minutes plus 5 minutes for questions or buffer. Prep takes about 10 minutes including the syscall trace and KASLR stop. The full sequence needs a timed rehearsal; KoviD credential extraction remains optional.

Build from the repo root with `make`; open `build/01-rootkits/index.html` or `slides.pdf`. The adjacent `../lkmhunter` source and validation notes are the authority for recorded results. The earlier KoviD-only rehearsal guide is background.

KoviD 4.0.1 is recorded as working with kernel 6.8.0-147-generic. Verify each sample/kernel pair and the prepared guest switches before presenting. Local GDB is read-only memory inspection, not a stopped CPU debugger.
