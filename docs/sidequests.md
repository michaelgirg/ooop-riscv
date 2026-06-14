# Side Quests

A menu of optional projects to build on top of a working five-stage RV32I
pipeline. These are exploration tracks, not requirements for the current
pipeline or out-of-order milestones.

**Tags:** effort `[wknd]` weekend · `[1wk]` ~a week · `[multi]` multi-week.
Learning value `(L1)` solid · `(L2)` high · `(L3)` exceptional.

Some entries overlap the main architecture roadmap. Keep each experiment on
top of a passing baseline, and record correctness, CPI, frequency, area, and
power where those measurements apply.

## Ideas Moved from the README

The original README side quests are included here rather than duplicated:

- Standard `riscv-tests` and `riscv-arch-test` coverage: item 46
- Higher-frequency and deeper-pipeline studies: items 32 and 50
- Area and power studies: items 34 and 51
- Floating point: item 29
- Larger in-order and out-of-order designs: items 35 and the main roadmap
- RV64: the additional ISA-width project in section E

---

## A. Start here — make the core *measurable* (the force multiplier)

Without this, every other item is guesswork. With it, every item becomes a quantified experiment.

1. **Add a Verilator simulation path** `[wknd]` `(L2)` — keep Questa for the
   existing self-checking tests, then add Verilator plus a C++ harness for
   faster benchmark and software runs. This is a near-prerequisite for sections
   H, I, and N.
2. **Lock-step co-simulation vs Spike** `[1wk]` `(L3)` — run the official ISA reference sim
   (`riscv-isa-sim`/Spike) alongside your RTL, compare architectural state (PC, regfile, CSRs,
   memory writes) every retired instruction, halt on first divergence. This is *how real cores are
   verified* and it will find bugs you'd never hit by hand. Highest learning-per-effort on this list.
3. **CPI / performance-counter harness** `[wknd]` `(L2)` — wire up the `cycle` and `instret`
   CSRs (Zicntr), then decompose CPI into base + branch-mispredict + load-use + (later) cache-miss
   stall cycles. Now you can *attribute* every cycle. Pairs with the "iron law": time = IC × CPI × T.
4. **Benchmark suite** `[1wk]` `(L2)` — get Dhrystone (DMIPS/MHz), CoreMark, and Embench-IoT
   building with the GNU toolchain and running on your core. Compare your numbers to published
   results for picorv32 / VexRiscv / Rocket. Suddenly "is my core good?" has an answer.

---

## B. Control flow & branch prediction

5. **Resolve branches in ID instead of EX** `[wknd]` `(L2)` — add a comparator + target adder in ID
   to cut the taken-branch penalty from 2 cycles to 1. Teaches the classic latency/critical-path
   trade-off: you shrink the penalty but lengthen the ID stage and need extra forwarding into ID.
6. **Static predictor zoo** `[wknd]` `(L1)` — you have predict-not-taken; add predict-taken and
   **BTFNT** (backward-taken/forward-not-taken). BTFNT nails loops with almost no hardware — a great
   "free win" lesson. Measure MPKI for each.
7. **Dynamic predictor ladder** `[1wk]` `(L3)` — build them in order and measure each:
   1-bit → 2-bit saturating → two-level/correlating → **gshare**/gselect → local-history →
   **tournament/hybrid** (a meta-predictor choosing between two). This single ladder is a whole
   comp-arch course unit.
8. **Branch Target Buffer (BTB)** `[1wk]` `(L2)` — tagged, set-associative target cache so you can
   redirect fetch in IF without decoding. Design choices: index/tag, associativity, allocation
   policy.
9. **Return Address Stack (RAS)** `[wknd]` `(L3)` — a tiny stack that predicts `ret` targets;
   push on call (`jal`/`jalr` rd=x1/x5), pop on return. Cheap, big accuracy win on call-heavy code,
   and almost everyone overlooks it. Excellent effort-to-insight ratio.
10. **Why RISC-V has no delay slots** `[reading]` `(L1)` — implement/understand MIPS-style delayed
    branches conceptually to see the ISA-vs-µarch tension, then appreciate why RV dropped them.

---

## C. Memory hierarchy (the richest learning area)

11. **Direct-mapped I-cache and D-cache** `[1wk]` `(L3)` — first real caches. Miss FSM that stalls
    the pipe, tag/data arrays, valid bits. This is where "memory wall" stops being abstract.
12. **Set-associativity + replacement** `[1wk]` `(L2)` — 2/4-way, then replacement policies:
    LRU, **tree-pseudo-LRU**, FIFO, random. Measure miss-rate vs associativity — the classic curve.
13. **Write policy study** `[wknd]` `(L2)` — write-through vs **write-back**, write-allocate vs
    not, plus a **write buffer**. Each changes both correctness corner-cases and performance.
14. **Store buffer + store-to-load forwarding** `[1wk]` `(L2)` — even in-order, this hides store
    latency and teaches the memory-disambiguation problem you'll meet again in the LSQ for OoO.
15. **Non-blocking cache / MSHRs** `[multi]` `(L3)` — let the pipe keep going under a miss; track
    outstanding misses in Miss Status Holding Registers. The gateway to memory-level parallelism.
16. **Prefetching** `[wknd]` `(L2)` — next-line, then stride prefetchers; measure coverage vs
    pollution. Small hardware, surprisingly deep design space.
17. **Sv32 MMU + page-table walker** `[multi]` `(L3)` — RV32 virtual memory: 2-level page tables,
    4KB pages, the `satp` CSR, a hardware **TLB**, and a walker FSM. Big lift, but it's the gate to
    running an OS (item I) and one of the most educational single modules you can build.
18. **C model of the cache first** `[wknd]` `(L2)` — write a trace-driven cache simulator in C/Python
    to sweep the design space in seconds, *then* build the winning config in RTL. Teaches the
    sim-before-RTL methodology real teams use.

---

## D. Privilege, CSRs, traps & interrupts

19. **CSR file (Zicsr)** `[1wk]` `(L2)` — `mstatus`, `mtvec`, `mepc`, `mcause`, `mtval`, `mie`,
    `mip`, `mscratch`, `misa`, `mhartid`, counters. This is the dependency your riscv-tests harness
    already needs, and it unblocks D/H/I. **[partially on your fault-handling task]**
20. **Precise machine-mode trap handling** `[1wk]` `(L3)` — illegal-instruction, misaligned
    load/store, ECALL/EBREAK; squash the faulting instruction in its own stage, capture mepc/mcause,
    redirect to mtvec, return via `mret`. "Precise exceptions in a pipeline" is a canonical hard
    problem and you'll feel exactly why.
21. **CLINT — timer & software interrupts** `[wknd]` `(L2)` — `mtime`/`mtimecmp`/`msip`. First
    asynchronous events; teaches interrupt entry/exit and re-entrancy.
22. **PLIC — external interrupts** `[1wk]` `(L2)` — prioritized external IRQs from peripherals.
    Needed for a UART-driven OS.
23. **Add S-mode and U-mode** `[multi]` `(L3)` — the privilege stack that real software assumes.
    Trap delegation (`medeleg`/`mideleg`), `sret`, the whole M/S/U model. Prereq for Linux.
24. **PMP (physical memory protection)** `[wknd]` `(L2)` — region-based access control in M-mode;
    a small, self-contained intro to hardware protection.

---

## E. ISA extensions (each is a self-contained project)

25. **M — multiply/divide** `[1wk]` `(L3)` — `mul`/`mulh*`/`div*`/`rem*`. Build a multiplier
    (single-cycle → multi-cycle → pipelined) and an iterative divider (restoring → non-restoring →
    SRT). Forces your *first variable-latency functional unit*, which means structural hazards and a
    mini in-order scoreboard even before OoO. Hugely instructive.
26. **C — compressed (16-bit)** `[1wk]` `(L3)` — 16-bit instructions that can sit on 2-byte
    boundaries, so 32-bit instructions can straddle words. Rebuilds your fetch/align logic and
    interacts directly with your BRAM sync-read concern. Great fetch-engine lesson.
27. **A — atomics** `[1wk]` `(L2)` — `lr.w`/`sc.w` and the AMOs. Your first taste of memory ordering
    and read-modify-write at the memory interface; prereq for multicore.
28. **Zbb/Zba/Zbs — bit-manip** `[wknd]` `(L1)` — small, fun, mostly ALU work; good warm-up and
    real code speedups.
29. **F/D — floating point** `[multi]` `(L3)` — IEEE-754, a separate FP register file, rounding
    modes, FMA. Large but teaches arithmetic datapath design and a second register file with its own
    hazards. Optional but deep.
30. **Design your own custom instruction** `[wknd]` `(L2)` — use a reserved opcode, extend the
    decoder + datapath, expose it via inline asm. Teaches the *mechanics* of extending an ISA end-to-end.

**RV64 — widen the architecture** `[multi]` `(L3)` — widen the datapath,
register file, addresses, memories, and architectural state to 64 bits. Add
RV64I's 32-bit word operations and verify sign-extension rules. This is a large
cross-cutting project and is best attempted as a separate core configuration.

---

## F. In-order microarchitecture refinements

31. **Complete the forwarding network** `[wknd]` `(L2)` — make sure WB→ID (same-cycle write/read,
    "double-bumped" regfile), WB→EX, and MEM→EX are all covered; hunt the corner cases (back-to-back
    dependent loads, CSR-read hazards).
32. **Superpipelining** `[multi]` `(L2)` — split stages to push Fmax; watch IPC drop as the pipeline
    deepens and hazards multiply. The depth-vs-IPC-vs-frequency trade-off made concrete.
33. **Variable-latency unit integration** `[1wk]` `(L2)` — fold the multiplier (item 25) into the
    in-order pipe with a scoreboard-style stall; the smallest possible taste of dynamic scheduling.
34. **Clock-gating / power awareness** `[wknd]` `(L1)` — gate idle units; if on FPGA, observe the
    resource/toggle impact. Power is the third axis after performance and area.

---

## G. In-order superscalar — the bridge to OoO

35. **Dual-issue in-order** `[multi]` `(L3)` — fetch 2 / decode 2 / issue 2 with inter-pair
    dependency checks, two ALUs, and more regfile ports (think original Pentium U/V pipes, or
    Cortex-A53). This is the *ideal* stepping stone between your scalar pipe and full OoO: you learn
    issue logic, structural hazards, and N-wide complexity without rename/ROB yet. **[precedes your
   OoO phase.
36. **VLIW as a contrast** `[reading]` `(L1)` — understand compiler-scheduled issue to see what
    hardware OoO buys you and why both exist.

---

## H. SoC integration & booting software

37. **Real bus protocol** `[1wk]` `(L2)` — wrap memory + peripherals behind **AXI4-Lite**,
    **Wishbone**, or **TileLink**. Interconnect design is a core skill RTL courses skip.
38. **Peripherals: UART, GPIO, SPI, timer** `[1wk]` `(L2)` — memory-mapped I/O, `printf` over UART.
    The moment your core feels alive.
39. **Boot ROM + UART bootloader** `[wknd]` `(L2)` — load programs over serial instead of
    re-synthesizing. Quality-of-life that also teaches the boot flow.
40. **Run an RTOS (FreeRTOS / Zephyr)** `[1wk]` `(L3)` — needs traps + timer + CSRs (items 19–22).
    Context switching on *your* silicon is a milestone.

---

## I. The privilege summit — boot an OS / Linux

41. **Boot Linux** `[multi]` `(L3)` — the ultimate in-order milestone. Requires Sv32 MMU (17),
    M/S/U modes (23), CLINT+PLIC (21–22), and a stable trap path (20). Months of work, but you end up
    understanding the *entire* hardware/software contract. picorv32 can't do this; a Sv32 core can —
    that gap is exactly the learning.

---

## J. Multicore, coherence & memory consistency

42. **Multi-hart** `[1wk]` `(L2)` — replicate the core over shared memory; `mhartid`, per-hart CSRs.
43. **Cache coherence** `[multi]` `(L3)` — implement **MSI**, then **MESI/MOESI** snooping. One of
    the deepest subfields; even a 2-core MSI teaches the core ideas.
44. **Memory consistency (RVWMO) + fences** `[1wk]` `(L3)` — implement and test `fence`/`fence.i`
    against the RISC-V weak memory model. The difference between coherence and consistency is a
    classic point of confusion you'll resolve by building it.
45. **Hardware multithreading** `[1wk]` `(L2)` — 2-way fine-grained (barrel-style) multithreading
    hides latency cheaply on an in-order pipe. Cool, underappreciated, and a nice contrast to OoO's
    approach to the same problem.

---

## K. Verification & formal (deepen the methodology)

46. **riscv-tests + riscv-arch-test** `[1wk]` `(L2)` — the official functional and compliance
    suites. Needs your CSR/ECALL harness. **[flagged in your notes]**
47. **riscv-formal (bounded model checking)** `[1wk]` `(L3)` — YosysHQ's framework formally proves
    your core matches the ISA on bounded traces. Your intro to formal methods, and it finds bugs
    simulation never will.
48. **Random instruction generation / fuzzing** `[1wk]` `(L2)` — riscv-dv or a homemade generator
    feeding the Spike co-sim (item 2). Coverage you can't write by hand.
49. **SVA assertions + functional coverage** `[1wk]` `(L2)` — invariants on
    hazards, one-hot control, and pipeline-valid propagation. Treat this as a
    future tool/license side quest. The current Questa Starter flow should keep
    using procedural self-checking testbenches rather than making SVA a
    dependency.

---

## L. FPGA, timing & ASIC

50. **Timing closure** `[1wk]` `(L3)` — find the critical path, hit Fmax, then *fix* it: retime,
    add pipeline stages, restructure. Where RTL meets physics. **[Phase 1.5]**
51. **Inference discipline** `[wknd]` `(L2)` — BRAM for caches/regfile (your sync-read gotcha), DSP
    blocks for the multiplier; read utilization (LUT/FF/BRAM/DSP) as an area budget. **[Phase 1.5]**
52. **On-board bring-up** `[1wk]` `(L2)` — UART + LEDs, debug with an ILA. Real hardware bugs.
53. **Open-source ASIC flow** `[multi]` `(L3)` — push the core through OpenLane/Sky130 to a GDS
    layout (tapeout-style). Synthesis → place → route → timing on a real PDK. Rare and impressive
    learning.

---

## M. Security & modern topics

54. **Speculation side channels** `[reading→1wk]` `(L3)` — once you have prediction (B), study
    Spectre-style leakage; understand why speculation has security cost. Ties your µarch choices to
    a very current research thread.
55. **PMP / CFI / pointer masking** `[wknd]` `(L2)` — hardware protection features; PMP (item 24) is
    the easy entry point.

---

## N. The experiments to actually run (this is the "comp arch" part)

Once item A is in place, *run studies*, don't just build features:

- **CPI decomposition** on each benchmark: how many cycles to branches vs loads vs cache misses?
- **Branch-predictor bake-off:** plot MPKI across the item-7 ladder on the same workloads.
- **Cache sensitivity sweep:** IPC vs cache size, associativity, line size, replacement policy.
- **Pipeline-depth study:** IPC vs Fmax as you deepen (item 32) — find the sweet spot.
- **Iron-law attribution:** for every change, report ΔIC, ΔCPI, ΔFmax separately, then net runtime.
- **Compare to published cores** (picorv32, VexRiscv, Rocket): where do you win/lose, and why?

These plots are exactly what a graduate comp-arch course project produces.

---

## O. Read alongside

- **Patterson & Hennessy — *Computer Organization and Design, RISC-V Edition*** — the pipeline you're
  building, from the source.
- **Hennessy & Patterson — *Computer Architecture: A Quantitative Approach*** — the bible for caches,
  ILP, OoO, multiprocessors, and the quantitative method (items C, G, J, N).
- **Onur Mutlu's lectures (ETH/CMU, free on YouTube)** — Digital Design & Comp Arch, then Comp Arch.
  Possibly the best free comp-arch teaching available.
- **RISC-V specs** — unprivileged (extensions) and privileged (CSRs, traps, MMU, RVWMO).
- **Read real RTL** — closest to your SystemVerilog stack: **Ibex** (lowRISC, 2-stage, very readable)
  and **CVA6/Ariane** (in-order, Linux-capable, SV). Then **Rocket** (in-order, MMU) and **BOOM**
  (OoO) in Chisel for the advanced ideas. **SERV**/**picorv32** for minimalism.

---

## If you want a recommended path (max learning before the next project)

1. **A1–A3** — Verilator + Spike co-sim + CPI harness. Everything downstream depends on it.
2. **D19–D20** — CSRs + precise traps. Unblocks tests, RTOS, and your own fault-handling task.
3. **E25** — M extension. First variable-latency unit → mini-scoreboard, a real µarch lesson.
4. **C11–C13** — caches + write policy. The memory wall, hands-on.
5. **B7 + B9** — gshare + RAS, measured against B6 baselines. The full prediction story.
6. **G35** — dual-issue in-order. The honest bridge into your planned OoO phase.

Anything past that (MMU → Linux, coherence, ASIC) is a deliberate deep-dive you can pick by taste.
