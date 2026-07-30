import ooo_pkg::*;

// In-order retirement and precise architectural side-effect controller.
//
// Owner: Mike
// Depends on: rob.sv and the store-commit side of memory_queue.sv
//
// Normal register instructions commit the rename map and release their stale
// physical destination. Stores wait for the memory queue to report that the
// D-cache transaction completed. Faulting instructions retire no side effects
// and request a precise trap using their own PC/cause/value.

module commit_unit (
    input logic clk,
    input logic rst,

    input  logic          rob_valid_i,
    input  var rob_commit_t rob_entry_i,
    output logic          rob_ready_o,

    // Committed-map update and stale-register release.
    output logic      map_commit_valid_o,
    output arch_reg_t map_commit_arch_o,
    output phys_reg_t map_commit_phys_o,
    output logic      free_release_valid_o,
    output phys_reg_t free_release_phys_o,

    // Stores become visible only through this retirement handshake.
    output logic     store_commit_valid_o,
    output rob_tag_t store_commit_tag_o,
    input  logic     store_commit_done_i,
    input  logic     store_commit_fault_i,

    // Precise trap and halt requests are consumed by ooo_control.sv.
    output logic             trap_valid_o,
    output logic [31:0]      trap_pc_o,
    output exception_cause_t trap_cause_o,
    output logic [31:0]      trap_value_o,
    output logic             halt_o,

    output var retire_event_t retire_o
);

    // TODO(Mike): Add the retirement state machine, store wait behavior,
    // exception-side-effect suppression, map/free updates, and retire event.

endmodule
