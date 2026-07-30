import ooo_pkg::*;

// Single-wide RV32IM out-of-order core integration shell.
//
// Owner: Together, implemented last
//
// This module contains the OOO core only. Its instruction- and data-cache
// ports intentionally match the CPU sides of the existing icache and dcache,
// allowing the current cache/backing-memory system to be reused unchanged.

module core_ooo (
    input logic clk,
    input logic rst,

    // Existing I-cache CPU-side interface.
    output logic        icache_req_valid_o,
    output logic [31:0] icache_req_addr_o,
    input  logic        icache_resp_valid_i,
    input  logic [31:0] icache_resp_data_i,
    input  logic        icache_resp_fault_i,
    input  logic        icache_stall_i,

    // Existing D-cache CPU-side request interface.
    output logic        dcache_req_valid_o,
    output logic        dcache_req_write_o,
    output logic [31:0] dcache_req_addr_o,
    output logic [31:0] dcache_req_wdata_o,
    output logic [2:0]  dcache_req_funct3_o,
    input  logic        dcache_req_ready_i,

    // Existing D-cache CPU-side response interface.
    output logic        dcache_resp_ready_o,
    input  logic        dcache_resp_valid_i,
    input  logic [31:0] dcache_resp_rdata_i,
    input  logic        dcache_resp_hit_i,
    input  logic        dcache_resp_miss_i,
    input  logic        dcache_resp_fault_i,

    // Minimal machine trap-vector input until the CSR file is added.
    input logic [31:0] trap_target_i,

    output logic [31:0] current_pc_o,
    output logic        halted_o,
    output logic        illegal_instruction_o,
    output logic        instruction_fault_o,
    output logic        data_fault_o,
    output var retire_event_t retire_o
);

    // TODO(Together): Instantiate and connect the frontend, rename structures,
    // ROB, queues, execution cluster, result arbiter, commit unit, and global
    // control only after each module passes independently.
    //
    // Integration invariants:
    // - ROB allocation and queue dispatch are one atomic transfer.
    // - Result-bus acceptance updates both PRF readiness and the matching ROB.
    // - Recovery reaches every speculative structure in the same cycle.
    // - No store reaches the D-cache before in-order commit authorizes it.

endmodule
