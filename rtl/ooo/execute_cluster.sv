import ooo_pkg::*;

// ALU, branch, jump, and RV32M execution cluster.
//
// Owner: Ant
// Depends on: issue_queue.sv and result_arbiter.sv
//
// ALU/branch results are short latency. MUL/DIV may remain active while newer
// ALU instructions execute. Every producer must hold a completed result until
// the result arbiter accepts it. Recovery must cancel a younger long-latency
// operation or prevent its eventual completion from becoming visible.

module execute_cluster (
    input logic clk,
    input logic rst,

    input  logic                   issue_valid_i,
    input  var execution_request_t issue_request_i,
    output logic                   issue_ready_o,

    input rob_tag_t            rob_head_tag_i,
    input var recovery_event_t recovery_i,

    // Completion producer presented to the common result arbiter.
    output logic            result_valid_o,
    output var completion_t result_o,
    input  logic            result_ready_i,

    // Branch resolution is accepted separately so redirect recovery does not
    // wait behind an unrelated result-bus completion.
    output logic                   branch_valid_o,
    output var branch_resolution_t branch_o,
    input  logic                   branch_ready_i
);

    // TODO(Ant): Integrate the existing ALU, branch unit, and muldiv unit;
    // calculate JAL/JALR links and targets; buffer colliding completions; and
    // enforce valid/ready stability for both result and branch outputs.

endmodule
