import ooo_pkg::*;

// Circular free list for physical destination registers.
//
// Owner: Mike
// Independent first task: yes
//
// Reset places p32 through p63 in the free list. A rename transfer removes one
// tag. Retirement returns the instruction's stale physical destination. Each
// branch saves the allocation pointer after its own destination allocation;
// recovery restores that pointer so younger allocations become free again.

module free_list (
    input logic clk,
    input logic rst,

    // Allocation uses a normal valid/ready handshake.
    output logic      allocate_valid_o,
    output phys_reg_t allocate_phys_o,
    input  logic      allocate_ready_i,

    // A stale destination is released only by successful retirement.
    input logic      release_valid_i,
    input phys_reg_t release_phys_i,

    // Save state immediately after any allocation made by the branch.
    input logic     checkpoint_save_valid_i,
    input rob_tag_t checkpoint_branch_tag_i,

    // Keep retirement-side releases, but undo allocations younger than the
    // recovering branch.
    input logic     recover_valid_i,
    input rob_tag_t recover_branch_tag_i,

    output logic empty_o,
    output logic full_o
);

    // TODO(Mike): Add the circular queue, extended head/tail pointers,
    // branch-indexed head checkpoints, release handling, and recovery logic.

endmodule
