import ooo_pkg::*;

// Physical register file for the single-wide OOO core.
//
// Owner: Mike
// Independent first task: yes
//
// Expected behavior:
// - Reset gives every register a known zero value. p0 through p31 are ready
//   because the reset rename map initially points architectural registers at
//   those physical registers; p32 through p63 begin free and not ready.
// - Allocating a destination marks that physical register not ready.
// - Accepting a matching result writes its value and marks it ready.
// - p0 ignores allocation and writeback and always reads as ready zero.
// - Squashed values do not need to be erased. The free list returns their
//   tags, and the next allocation clears readiness before reuse.

module physical_regfile (
    input logic clk,
    input logic rst,

    input  phys_reg_t   source_1_tag_i,
    input  phys_reg_t   source_2_tag_i,
    output logic [31:0] source_1_value_o,
    output logic [31:0] source_2_value_o,
    output logic        source_1_ready_o,
    output logic        source_2_ready_o,

    // One destination is allocated because rename is single-wide.
    input logic      allocate_valid_i,
    input phys_reg_t allocate_tag_i,

    // The common result bus is the only normal writeback source.
    input var result_bus_t result_i
);

    // TODO(Mike): Add the value array, ready-bit array, reset behavior,
    // allocation handling, writeback handling, and p0 protection. If the same
    // nonzero tag is allocated and written back together, allocation wins so a
    // stale result cannot make the newly allocated destination ready.

endmodule
