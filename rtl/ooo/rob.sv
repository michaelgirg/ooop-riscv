import ooo_pkg::*;

// Reorder buffer for precise, in-order retirement.
//
// Owner: Mike
// Independent after ooo_pkg.sv: yes
//
// Dispatch allocates one tail entry. Results may complete entries out of
// order, but only a complete head entry may retire. Recovery removes entries
// younger than the resolving branch and moves the tail behind that branch.

module rob (
    input logic clk,
    input logic rst,

    // Single-wide allocation. dispatch_tag_o is the tag rename must place in
    // dispatch_uop_i before the transfer is accepted.
    input  logic         dispatch_valid_i,
    input  var renamed_uop_t dispatch_uop_i,
    output logic         dispatch_ready_o,
    output rob_tag_t     dispatch_tag_o,

    // One completion per cycle from the common result bus.
    input var result_bus_t result_i,

    // Selective branch recovery.
    input var recovery_event_t recovery_i,

    // In-order head interface. The ROB advances only on valid && ready.
    output logic        commit_valid_o,
    output var rob_commit_t commit_o,
    input  logic        commit_ready_i,

    // Age reference used by issue and memory queues.
    output rob_tag_t head_tag_o,
    output logic     empty_o,
    output logic     full_o,
    output logic [ROB_INDEX_BITS:0] count_o
);

    // TODO(Mike): Add the entry array, wrapped head/tail tags, allocation,
    // full-tag completion matching, selective recovery, and head retirement.

endmodule
