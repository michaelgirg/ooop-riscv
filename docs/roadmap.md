# Roadmap

## M0: Infrastructure

- [x] Repository layout
- [x] Shared package and module interfaces
- [x] Questa scripts
- [x] Vivado synthesis script
- [x] Confirm ZedBoard device part (`xc7z020clg484-1`)
- [x] Install/configure Questa command-line access
- [x] Install/configure Vivado command-line access

## M1: Single-Cycle Core

- [x] Unit-test register file, ALU, immediate generator, and decoder
- [x] Implement the complete RV32I integer instruction set
- [x] Integrate combinational RV32M multiply/divide
- [x] Add byte and halfword memory operations
- [x] Detect illegal, misaligned, and out-of-range accesses
- [x] Run the complete directed regression
- [x] Synthesize in Vivado and record timing/utilization

## M2: Five-Stage Pipeline

- [x] IF/ID, ID/EX, EX/MEM, and MEM/WB registers
- [x] Data forwarding and load-use stalls
- [x] Control-hazard flush and same-cycle WB-to-ID bypass
- [x] Integrate variable-latency RV32M execution
- [x] Integrate direct-mapped I-cache and set-associative D-cache
- [x] Add delayed backing-memory line interfaces
- [x] Verify redirect, MUL/DIV, dirty-eviction, and cache-fault overlaps
- [x] Add differential register/memory checking and event counters
- [x] Prove exactly-once stores and MUL/DIV issue across cache stalls
- [x] Close post-route timing at 100 MHz on ZedBoard

## M3: Single-Wide Out-of-Order Core

- [x] Single-wide fetch, decode, rename, dispatch, and retirement
- [x] Physical register file and speculative/committed rename maps
- [x] Checkpointed free list and branch recovery
- [x] Generation-tagged reorder buffer
- [x] Issue queue with common-result-bus wakeup and oldest-ready select
- [x] ALU, branch/jump, and variable-latency RV32M execution
- [x] Fair execution/memory result arbitration
- [x] Conservative memory queue with head-only loads and commit-authorized stores
- [x] Precise in-order exceptions, halt, and exactly-once stores
- [x] Module-level Questa regression
- [x] Full-core dependency, memory, branch-recovery, and halt integration test

## M4: OOO Expansion

- [ ] Add retirement-based differential checking against Spike or a reference model
- [ ] Add cycle, issue, recovery, and queue-occupancy performance counters
- [ ] Add branch prediction and checkpoint-pressure measurements
- [ ] Add a store buffer and speculative load/store ordering checks
- [ ] Expand to two-wide rename, dispatch, result handling, and retirement
- [ ] Integrate multicore caches and a small coherence protocol
- [ ] Add UVM after the architectural interfaces stabilize

Each completed milestone keeps its own passing regression before the next
architecture reuses or extends it.
