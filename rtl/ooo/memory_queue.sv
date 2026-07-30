import ooo_pkg::*;

// Conservative load/store queue for the first OOO core.
//
// Owner: Together
// Depends on: ROB head/age, result arbiter, recovery, and commit unit
//
// This first version may calculate memory addresses out of order, but a load
// accesses the D-cache only when it reaches the ROB head. A store accesses the
// D-cache only after commit_unit explicitly authorizes that ROB tag. This is
// intentionally conservative and gives precise, exactly-once stores before a
// speculative load/store queue is attempted.

module memory_queue (
    input logic clk,
    input logic rst,

    input  logic                 dispatch_valid_i,
    input  var dispatch_packet_t dispatch_packet_i,
    output logic                 dispatch_ready_o,

    input var result_bus_t result_i,

    input rob_tag_t            rob_head_tag_i,
    input var recovery_event_t recovery_i,
    input logic                flush_all_i,

    // Load completion or store-address completion to the result arbiter.
    output logic            result_valid_o,
    output var completion_t result_o,
    input  logic            result_ready_i,

    // Store authorization from the in-order commit unit.
    input  logic     store_commit_valid_i,
    input  rob_tag_t store_commit_tag_i,
    output logic     store_commit_done_o,
    output logic     store_commit_fault_o,

    // Existing D-cache CPU-side interface.
    output logic        dcache_req_valid_o,
    output logic        dcache_req_write_o,
    output logic [31:0] dcache_req_addr_o,
    output logic [31:0] dcache_req_wdata_o,
    output logic [2:0]  dcache_req_funct3_o,
    input  logic        dcache_req_ready_i,

    output logic        dcache_resp_ready_o,
    input  logic        dcache_resp_valid_i,
    input  logic [31:0] dcache_resp_rdata_i,
    input  logic        dcache_resp_hit_i,
    input  logic        dcache_resp_miss_i,
    input  logic        dcache_resp_fault_i,

    output logic full_o,
    output logic empty_o
);

    // TODO(Together): Add source wakeup, address/data calculation, oldest-load
    // selection, one-outstanding-request tracking, response buffering, store
    // authorization, exactly-once request behavior, and selective recovery.

endmodule
