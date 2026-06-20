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

## Verification And Measurement

1. **Verilator simulation path** `[wknd]` `(L2)`
   Keep Questa for the current self-checking tests, then add Verilator plus a C++ harness for faster benchmark runs.
2. **Spike lockstep co-simulation** `[1wk]` `(L3)`
   Compare retired PC, register writes, memory writes, and trap behavior against the RISC-V ISA simulator.
3. **CPI/performance counters** `[wknd]` `(L2)`
   Add cycle and instruction-retired counters, then count load-use stalls, branch flushes, and later cache misses.
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
    Add a multi-cycle multiplier/divider and stall or scoreboard around it.

## Memory Hierarchy

12. **Direct-mapped I-cache and D-cache** `[1wk]` `(L3)`
    Add tag/data arrays, valid bits, miss FSMs, and pipeline stalls.
13. **Set associativity and replacement** `[1wk]` `(L2)`
    Try 2-way or 4-way caches with FIFO, random, LRU, or pseudo-LRU replacement.
14. **Write policy study** `[wknd]` `(L2)`
    Compare write-through vs write-back and write-allocate vs no-write-allocate.
15. **Store buffer and store-to-load forwarding** `[1wk]` `(L2)`
    Useful bridge from in-order memory handling to the later out-of-order load/store queue.
16. **Trace-driven cache model first** `[wknd]` `(L2)`
    Simulate cache choices in Python or C before committing to RTL.

## ISA Extensions

17. **M extension** `[1wk]` `(L3)`
    Add multiply/divide and learn variable-latency functional-unit control.
18. **C extension** `[1wk]` `(L3)`
    Add 16-bit compressed instructions and rebuild fetch alignment logic.
19. **A extension** `[1wk]` `(L2)`
    Add LR/SC and AMO operations as a first memory-ordering project.
20. **Bit manipulation** `[wknd]` `(L1)`
    Add small ALU operations from Zbb/Zba/Zbs.
21. **Floating point** `[multi]` `(L3)`
    Add an FP register file, IEEE-754 operations, rounding modes, and FP hazards.
22. **RV64 version** `[multi]` `(L3)`
    Widen datapath, registers, memories, immediates, and add RV64I word-operation rules.

## Privilege, Traps, And Software

23. **Minimal CSR file** `[1wk]` `(L2)`
    Add machine-mode CSRs needed for tests, traps, counters, and basic software bring-up.
24. **Precise traps** `[1wk]` `(L3)`
    Capture `mepc`/`mcause`, squash correctly, redirect to `mtvec`, and return with `mret`.
25. **Timer and interrupts** `[1wk]` `(L2)`
    Add CLINT-style timer/software interrupts and eventually external interrupts.
26. **UART/GPIO SoC shell** `[1wk]` `(L2)`
    Add memory-mapped peripherals so software can print and interact with the outside world.
27. **Bootloader or tiny C runtime** `[1wk]` `(L2)`
    Add linker script, startup code, objcopy-to-hex flow, and a simple C program.
28. **RTOS or Linux path** `[multi]` `(L3)`
    Requires traps, CSRs, timer, MMU for Linux, and a much stronger verification story.

## Bigger Architectures

29. **Dual-issue in-order** `[multi]` `(L3)`
    Learn issue logic, structural hazards, and extra register-file ports before full OOO.
30. **Out-of-order core** `[multi]` `(L3)`
    Add rename, physical registers, reservation stations, ROB, wakeup/select, and in-order retirement.
31. **Multicore and coherence** `[multi]` `(L3)`
    Add multiple harts and a small coherence protocol such as MSI.

## FPGA, Area, And Power

32. **Vivado timing/utilization reports** `[wknd]` `(L1)`
    Synthesize the single-cycle and pipeline cores, then record LUTs, FFs, BRAMs, DSPs, and Fmax.
33. **Area and power study** `[wknd]` `(L1)`
    Compare design choices by resource count and switching/power estimates.
34. **FPGA bring-up** `[1wk]` `(L2)`
    Add board wrapper, clock/reset, UART, LEDs, and ILA debug.
35. **Open-source ASIC flow** `[multi]` `(L3)`
    Try OpenLane/Sky130 for synthesis, place, route, and timing closure.

## Recommended Path

1. Verilator or faster simulation harness.
2. Spike lockstep or stronger architectural checking.
3. Minimal CSRs and precise traps.
4. M extension or cache work.
5. Branch prediction and CPI measurement.
6. Dual-issue or out-of-order exploration.
