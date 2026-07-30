import ooo_pkg::*;

// Single-instruction fetch and decode frontend.
//
// Owner: Ant
// Independent first task: yes
//
// Version one predicts every conditional branch as not taken. The frontend
// must hold a fetched/decoded instruction until rename accepts it and must
// discard wrong-path buffered work when redirect_valid_i is asserted.

module ooo_frontend (
    input logic clk,
    input logic rst,

    input logic        redirect_valid_i,
    input logic [31:0] redirect_pc_i,

    output logic             decoded_valid_o,
    output var decoded_uop_t decoded_uop_o,
    input  logic             decoded_ready_i,

    // Existing I-cache CPU-side interface.
    output logic        icache_req_valid_o,
    output logic [31:0] icache_req_addr_o,
    input  logic        icache_resp_valid_i,
    input  logic [31:0] icache_resp_data_i,
    input  logic        icache_resp_fault_i,
    input  logic        icache_stall_i,

    output logic [31:0] fetch_pc_o
);

    // TODO(Ant): Add the PC, one-entry fetch/decode buffer, existing decoder
    // and immediate-generator integration, predict-not-taken metadata, and
    // redirect priority over a returning wrong-path I-cache response.

endmodule
