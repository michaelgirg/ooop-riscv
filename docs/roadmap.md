# Roadmap

## M0: Infrastructure

- [x] Repository layout
- [x] Shared package and module interfaces
- [x] Questa scripts
- [x] Vivado synthesis script
- [ ] Confirm FPGA board and device part
- [ ] Install/configure Questa and Vivado command-line access

## M1: Single-Cycle Core

- [ ] Unit-test register file
- [ ] Unit-test ALU
- [ ] Unit-test immediate generator
- [ ] Unit-test decoder
- [ ] Integrate `ADDI`, `ADD`, `SUB`, `LW`, and `SW`
- [ ] Add branches and jumps
- [ ] Add remaining RV32I integer operations
- [ ] Add byte and halfword memory operations
- [ ] Run complete directed regression
- [ ] Synthesize in Vivado and record timing/utilization

## M2: Five-Stage Pipeline

- [ ] IF/ID, ID/EX, EX/MEM, and MEM/WB registers
- [ ] Data forwarding
- [ ] Load-use stall
- [ ] Control-hazard flush
- [ ] Pipeline integration regression

## M3: Out-of-Order Core

- [ ] Physical register file and rename maps
- [ ] Free list
- [ ] Reorder buffer
- [ ] Issue queue and wakeup/select
- [ ] In-order retirement
- [ ] Branch recovery
- [ ] Conservative load/store queue

Each milestone gets its own passing regression before work begins on the next.
