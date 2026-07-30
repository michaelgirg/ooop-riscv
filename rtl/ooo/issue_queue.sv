import ooo_pkg::*;

// Integer, branch, jump, and MUL/DIV issue queue.
//
// Owner: Ant
// Depends on: result-bus contract and ROB recovery/age contract
//
// Each source begins ready with a value or waiting on a physical tag. An
// accepted result bus broadcast wakes every matching source. Selection chooses
// the oldest ready instruction that its execution unit can currently accept.

module issue_queue (
    input logic clk,
    input logic rst,

    input  logic                 dispatch_valid_i,
    input  var dispatch_packet_t dispatch_packet_i,
    output logic                 dispatch_ready_o,

    input var result_bus_t result_i,

    input rob_tag_t            rob_head_tag_i,
    input var recovery_event_t recovery_i,

    output logic                   issue_valid_o,
    output var execution_request_t issue_request_o,
    input  logic                   issue_ready_i,

    output logic full_o,
    output logic empty_o
);

    // TODO(Ant): Add the entry array, result-bus wakeup, oldest-ready select,
    // valid/ready removal, and selective invalidation of younger entries.

endmodule
