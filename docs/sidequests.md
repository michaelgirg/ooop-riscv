# Side Quests

These are optional expansion projects for after the single-cycle and five-stage
pipeline baselines are passing. Treat them like experiments: start from a clean
passing regression, make one change, then record correctness, CPI, frequency,
area, and power when those numbers apply.

Effort tags:

- `[wknd]`: weekend-sized
- `[1wk]`: about one week
- `[multi]`: multi-week project

Learning tags:

- `(L1)`: useful
- `(L2)`: high value
- `(L3)`: very high value

Completed foundations are kept in this list when they still have useful
follow-on experiments. RV32M, variable-latency MUL/DIV, direct-mapped I-cache,
set-associative write-back D-cache, tree PLRU, the 100 MHz pipeline baseline,
and the single-wide OOO core are already implemented.

## Verification And Measurement

1. **Verilator simulation path** `[wknd]` `(L2)`
   Keep Questa for the current self-checking tests, then add Verilator plus a C++ harness for faster benchmark runs.
2. **Spike lockstep co-simulation** `[1wk]` `(L3)`
   Compare retired PC, register writes, memory writes, and trap behavior against the RISC-V ISA simulator.
3. **CPI/performance counters** `[wknd]` `(L2)`
   Pipeline counters exist; add equivalent OOO issue, recovery, queue-occupancy, and memory-wait counters.
4. **Official `riscv-tests` / `riscv-arch-test`** `[1wk]` `(L2)`
   This likely needs a small CSR/ECALL/tohost harness or a custom test wrapper.
5. **Random instruction testing** `[1wk]` `(L2)`
   Use a small homemade generator or riscv-dv later, ideally checked against Spike.
6. **Formal or assertions later** `[1wk]` `(L3)`
   Keep the current Questa Starter flow procedural for now. SVA/formal can become a future tool sidequest.

## Pipeline Improvements

7. **Resolve branches in ID** `[wknd]` `(L2)`
   Reduces taken-branch penalty from two cycles to one, but adds forwarding and timing pressure in ID.
8. **Branch prediction** `[1wk]` `(L3)`
   Try static prediction, 1-bit/2-bit counters, then gshare and a small BTB.
9. **Return address stack** `[wknd]` `(L3)`
   Predict function returns from `jal`/`jalr` call and return patterns.
10. **Deeper pipeline / higher frequency** `[multi]` `(L2)`
    Split stages, measure Fmax, and compare the frequency gain against extra bubbles and branch penalty.
11. **Variable-latency units** `[1wk]` `(L2)`
    Completed for RV32M. Compare the existing iterative divider and multiplier against pipelined or radix-4 alternatives.

## Memory Hierarchy

12. **Direct-mapped I-cache and D-cache** `[1wk]` `(L3)`
    The I-cache baseline is direct mapped. A direct-mapped D-cache remains useful only as an area/timing comparison.
13. **Set associativity and replacement** `[1wk]` `(L2)`
    The D-cache already supports parameterized associativity and tree PLRU; compare it with FIFO, random, or true LRU.
14. **Write policy study** `[wknd]` `(L2)`
    Compare write-through vs write-back and write-allocate vs no-write-allocate.
15. **Store buffer and store-to-load forwarding** `[1wk]` `(L2)`
    Upgrade the conservative OOO memory queue so older stores can wait while safe younger loads continue.
16. **Trace-driven cache model first** `[wknd]` `(L2)`
    Simulate cache choices in Python or C before committing to RTL.
17. **Pipelined I-cache hit path** `[wknd]` `(L3)`
    Register tag/data lookup and carry request PC/valid metadata through fetch. Do this only after timing reports identify the flow-through I-cache hit as a critical path.

### Cache Integration Rule

When a D-cache miss back-pressures MEM, hold `EX/MEM`, `ID/EX`, and the front of
the pipeline. A completed MUL/DIV result must remain valid until EX/MEM accepts
it; do not allow the held instruction to reissue after the unit finishes.

## ISA Extensions

18. **M extension** `[1wk]` `(L3)`
    Completed across the single-cycle, pipeline, and single-wide OOO cores; performance optimization remains open.
19. **C extension** `[1wk]` `(L3)`
    Add 16-bit compressed instructions and rebuild fetch alignment logic.
20. **A extension** `[1wk]` `(L2)`
    Add LR/SC and AMO operations as a first memory-ordering project.
21. **Bit manipulation** `[wknd]` `(L1)`
    Add small ALU operations from Zbb/Zba/Zbs.
22. **Floating point** `[multi]` `(L3)`
    Add an FP register file, IEEE-754 operations, rounding modes, and FP hazards.
23. **RV64 version** `[multi]` `(L3)`
    Widen datapath, registers, memories, immediates, and add RV64I word-operation rules.

## Privilege, Traps, And Software

24. **Minimal CSR file** `[1wk]` `(L2)`
    Add machine-mode CSRs needed for tests, traps, counters, and basic software bring-up.
25. **Precise traps** `[1wk]` `(L3)`
    The OOO core already retires exceptions precisely and squashes speculative state. Add `mepc`, `mcause`, `mtvec`, and `mret` for architectural trap handling.
26. **Timer and interrupts** `[1wk]` `(L2)`
    Add CLINT-style timer/software interrupts and eventually external interrupts.
27. **UART/GPIO SoC shell** `[1wk]` `(L2)`
    Add memory-mapped peripherals so software can print and interact with the outside world.
28. **Bootloader or tiny C runtime** `[1wk]` `(L2)`
    Add linker script, startup code, objcopy-to-hex flow, and a simple C program.
29. **RTOS or Linux path** `[multi]` `(L3)`
    Requires traps, CSRs, timer, MMU for Linux, and a much stronger verification story.

## Bigger Architectures

30. **Dual-issue in-order** `[multi]` `(L3)`
    Learn issue logic, structural hazards, and extra register-file ports before full OOO.
31. **Out-of-order core** `[multi]` `(L3)`
    The single-wide baseline now has rename, physical registers, issue/wakeup, a ROB, branch recovery, conservative memory ordering, and in-order retirement. Extend it with prediction, a speculative LSQ, or wider dispatch.
32. **Multicore and coherence** `[multi]` `(L3)`
    Add multiple harts and a small coherence protocol such as MSI.

## FPGA, Area, And Power

33. **Vivado timing/utilization reports** `[wknd]` `(L1)`
    Single-cycle and pipeline reports are recorded; synthesize the OOO core and compare LUTs, FFs, BRAMs, DSPs, and Fmax.
34. **Area and power study** `[wknd]` `(L1)`
    Compare design choices by resource count and switching/power estimates.
35. **FPGA bring-up** `[1wk]` `(L2)`
    Add board wrapper, clock/reset, UART, LEDs, and ILA debug.
36. **Open-source ASIC flow** `[multi]` `(L3)`
    Try OpenLane/Sky130 for synthesis, place, route, and timing closure.

## Recommended Path

1. Spike lockstep and randomized retirement checking.
2. OOO performance and occupancy counters.
3. Minimal machine CSRs and architectural trap return.
4. Branch prediction with measured recovery cost.
5. Store buffer, forwarding, and a speculative load/store queue.
6. Two-wide superscalar rename, dispatch, completion, and retirement.
7. Multicore cache coherence, followed by UVM once interfaces stabilize.
