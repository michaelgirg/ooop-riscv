# Roadmap

## M0: Infrastructure

- [x] Repository layout
- [x] Shared package and module interfaces
- [x] Questa scripts
- [x] Vivado synthesis script
- [x] Confirm ZedBoard device part (`xc7z020clg484-1`)
- [x] Install/configure Questa command-line access
- [ ] Install/configure Vivado command-line access

## M1: Single-Cycle Core

- [x] Unit-test register file
- [x] Unit-test ALU
- [x] Unit-test immediate generator
- [x] Unit-test decoder
- [x] Integrate `ADDI`, `ADD`, `SUB`, `LW`, and `SW`
- [x] Add branches and jumps
- [x] Add remaining RV32I integer operations
- [x] Add byte and halfword memory operations
- [x] Detect illegal, misaligned, and out-of-range accesses
- [x] Run complete directed regression
- [ ] Synthesize in Vivado and record timing/utilization

## M2: Five-Stage Pipeline

- [x] IF/ID, ID/EX, EX/MEM, and MEM/WB registers
- [x] Data forwarding
- [x] Load-use stall
- [x] Control-hazard flush
- [x] Pipeline top-level integration smoke test
- [x] Integrate direct-mapped I-cache and set-associative D-cache
- [x] Add delayed backing-memory line interfaces
- [x] Verify redirect, MUL/DIV, dirty-eviction, and cache-fault overlaps
- [x] Add more directed hazard programs beyond the smoke test
- [x] Add fault/flush integration tests for the pipeline
- [ ] Synthesize in Vivado and record timing/utilization

## M3: Out-of-Order Core

- [ ] Physical register file and rename maps
- [ ] Free list
- [ ] Reorder buffer
- [ ] Issue queue and wakeup/select
- [ ] In-order retirement
- [ ] Branch recovery
- [ ] Conservative load/store queue

Each milestone gets its own passing regression before work begins on the next.
