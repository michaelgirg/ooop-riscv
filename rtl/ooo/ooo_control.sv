import ooo_pkg::*;

// Global redirect, branch recovery, precise trap, and halt control.
//
// Owner: Together
// Depends on: execute_cluster.sv, commit_unit.sv, and all recovery consumers
//
// Priority is precise trap, halt, then branch misprediction. A branch recovery
// preserves the branch and older work. A precise trap flushes all speculative
// state and redirects to trap_target_i after the faulting head instruction has
// been handled by commit.

module ooo_control (
    input logic clk,
    input logic rst,

    input  var branch_resolution_t branch_i,
    output logic                   branch_ready_o,

    input logic             trap_valid_i,
    input logic [31:0]      trap_pc_i,
    input exception_cause_t trap_cause_i,
    input logic [31:0]      trap_value_i,
    input logic [31:0]      trap_target_i,
    input logic             halt_i,

    output var recovery_event_t recovery_o,
    output logic                flush_all_o,
    output logic                redirect_valid_o,
    output logic [31:0]         redirect_pc_o,

    output logic             trap_taken_o,
    output logic [31:0]      trap_pc_o,
    output exception_cause_t trap_cause_o,
    output logic [31:0]      trap_value_o,
    output logic             halted_o
);

    // TODO(Together): Add event priority, one-shot acceptance, branch recovery
    // generation, precise-trap flush/redirect, and sticky halt behavior.

endmodule
