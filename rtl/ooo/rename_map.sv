import ooo_pkg::*;

// Speculative and committed architectural-to-physical rename maps.
//
// Owner: Mike
// Independent first task: yes
//
// The speculative map supplies source tags during rename. The committed map
// changes only at retirement. Each control-flow instruction saves a complete
// speculative checkpoint after that instruction's own destination rename has
// been applied. Recovery restores the checkpoint selected by branch_tag.

module rename_map (
    input logic clk,
    input logic rst,

    // Combinational source and stale-destination lookups.
    input  arch_reg_t source_1_arch_i,
    input  arch_reg_t source_2_arch_i,
    input  arch_reg_t destination_arch_i,
    output phys_reg_t source_1_phys_o,
    output phys_reg_t source_2_phys_o,
    output phys_reg_t stale_destination_phys_o,

    // Physical registers referenced by the committed architectural map.
    // The free list uses this mask to rebuild itself after a precise trap.
    output phys_reg_mask_t committed_phys_in_use_o,

    // Accepted speculative destination rename.
    input logic      rename_valid_i,
    input arch_reg_t rename_arch_i,
    input phys_reg_t rename_phys_i,

    // Accepted architectural retirement update.
    input logic      commit_valid_i,
    input arch_reg_t commit_arch_i,
    input phys_reg_t commit_phys_i,

    // Save state immediately after the branch's rename is applied.
    input logic     checkpoint_save_valid_i,
    input var rob_tag_t checkpoint_branch_tag_i,

    // Restore the matching speculative checkpoint after a misprediction.
    input logic     recover_valid_i,
    input var rob_tag_t recover_branch_tag_i,

    // Precise traps discard every speculative mapping and restart from the
    // committed architectural map.
    input logic restore_committed_i
);

    // TODO(Mike): Add speculative and committed maps, branch-indexed map
    // checkpoints, committed-state restore, physical-register usage mask,
    // x0/p0 protection, and simultaneous rename/commit ordering. A checkpoint
    // save in the same cycle as a rename must include that rename. A commit and
    // speculative rename may update their separate maps in the same cycle.

endmodule
