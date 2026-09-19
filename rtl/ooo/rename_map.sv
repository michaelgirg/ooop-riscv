import ooo_pkg::*;

// Speculative and committed architectural-to-physical rename maps.
//
// Independent first task: yes
//
// The speculative map is used while instructions are still in progress.
// It tells rename which physical registers currently hold the source values.
//
// The committed map only updates when an instruction officially retires.
//
// When a branch or jump is renamed, the processor saves a copy of the
// speculative map (kinda like checkpoint) after applying that instruction's destination rename.
//
// If that branch was mispredicted, the processor restores the saved map
// belonging to that branch.

module rename_map (
    input logic clk,
    input logic rst,

    // arch source registers from the instruction being renamed
    input  arch_reg_t source_1_arch_i,
    input  arch_reg_t source_2_arch_i,
    input  arch_reg_t destination_arch_i,

    // Physical reg of our source regs
    output phys_reg_t source_1_phys_o,
    output phys_reg_t source_2_phys_o,
    output phys_reg_t stale_destination_phys_o, // this is the physical reg that currently represents the destination before it gets renamed

    // Physical registers referenced by the committed architectural map.
    // This is a bit mask showing which physical registers are referenced by the committed map.
    // The free list uses this mask to rebuild itself after a precise trap.
    output phys_reg_mask_t committed_phys_in_use_o,

    // Updates speculative map when rename is accepted with an instruction with a dest
    input logic      rename_valid_i,
    input arch_reg_t rename_arch_i,
    input phys_reg_t rename_phys_i,

    // updates the committed map when an instruction retires
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

    phys_reg_t speculative_map_q [0:ARCH_REG_COUNT-1]; // one physical reg tag for every arch reg (x0 & x1 is arch reg btw)
    phys_reg_t committed_map_q   [0:ARCH_REG_COUNT-1]; // same as above but for retired instructions only (safe state)

    phys_reg_t checkpoint_map_q [0:BRANCH_CHECKPOINTS-1] [0:ARCH_REG_COUNT-1]; // each checkpoint stores a complete copy of the speculative map
    rob_tag_t checkpoint_tag_q [0:BRANCH_CHECKPOINTS-1]; // records which full ROB tag owns each checkpoint
    logic     checkpoint_valid_q [0:BRANCH_CHECKPOINTS-1]; // records whether each checkpoint slot contains valid branch state

    always_comb begin
        // source and dest lookup
        source_1_phys_o = (source_1_arch_i == ARCH_ZERO) ? PHYS_ZERO : speculative_map_q[source_1_arch_i];
        source_2_phys_o = (source_2_arch_i == ARCH_ZERO) ? PHYS_ZERO : speculative_map_q[source_2_arch_i];
        stale_destination_phys_o = (destination_arch_i == ARCH_ZERO) ? PHYS_ZERO : speculative_map_q[destination_arch_i];

        committed_phys_in_use_o = '0;
        // find committed physical reg and set that mask bit
        for (int arch = 0; arch < ARCH_REG_COUNT; arch++) committed_phys_in_use_o[committed_map_q[arch]] = 1'b1;

        // x0/p0 is architectural state even if an invalid external update was
        // attempted, so the mask always reserves p0.
        committed_phys_in_use_o[PHYS_ZERO] = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst) begin // each arch reg maps to phy reg with same #
            for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin
                speculative_map_q[arch] <= phys_reg_t'(arch);
                committed_map_q[arch] <= phys_reg_t'(arch);
            end

            // Mark every checkpoint invalid
            for (int slot = 0; slot < BRANCH_CHECKPOINTS; slot++) begin
                checkpoint_valid_q[slot] <= 1'b0;
                checkpoint_tag_q[slot] <= '0;
                for (int arch = 0; arch < ARCH_REG_COUNT; arch++)
                    checkpoint_map_q[slot][arch] <= phys_reg_t'(arch);
            end
            // A trap is the CPU saying, “Something happened that requires special handling, so stop normal execution and go to the trap handler.”
        end else if (restore_committed_i) begin
            for (int arch = 0; arch < ARCH_REG_COUNT; arch++) //cpy entire committed map into the spec map so we return to the last known correct mapping
                speculative_map_q[arch] <= committed_map_q[arch];

            // A precise trap discards every speculative branch context.
            for (int slot = 0; slot < BRANCH_CHECKPOINTS; slot++)
                checkpoint_valid_q[slot] <= 1'b0;
        end else if (recover_valid_i) begin // recover from a branch misprediction
            if (checkpoint_valid_q[rob_index(recover_branch_tag_i)] &&
                (checkpoint_tag_q[rob_index(recover_branch_tag_i)] ==
                 recover_branch_tag_i)) begin
                for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin // cpy saved checkpoint into the spec map
                    speculative_map_q[arch] <= checkpoint_map_q[rob_index(recover_branch_tag_i)][arch];
                end
                checkpoint_valid_q[rob_index(recover_branch_tag_i)] <= 1'b0; // branch no longer needs that recovery state
            end
        end else begin
            // Commit and rename update independent maps and may happen in the
            // same cycle, including when they name the same architectural rd.
            /*
            For example, in one cycle:
            Older instruction commits: x5 → p40
            New instruction renames:    x5 → p52

            After the clock edge:=
            committed map:   x5 → p40
            speculative map: x5 → p52
            */
            if (commit_valid_i && (commit_arch_i != ARCH_ZERO)) committed_map_q[commit_arch_i] <= commit_phys_i; // update committed map when retiring instruction write an arch reg
            if (rename_valid_i && (rename_arch_i != ARCH_ZERO))speculative_map_q[rename_arch_i] <= rename_phys_i; // new dest is renamed we update spec map

            if (checkpoint_save_valid_i) begin //save branch checkpoint
                checkpoint_valid_q[rob_index(checkpoint_branch_tag_i)] <= 1'b1; // mark its slot valid
                checkpoint_tag_q[rob_index(checkpoint_branch_tag_i)] <= checkpoint_branch_tag_i; // record the full ROB tag belonging to the branch

                // Save the rename map as it should look after this instruction's rename.
                // Because nonblocking assignments have not updated speculative_map_q yet,
                // directly save rename_phys_i for the architectural register renamed now.
                for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin //cpy every arch mapping into the branch checkpoint
                    // special case: if the branch itself renamed this arch reg during the current cycle so u save the new physical mapping otherwise u do the existing spec mapping
                    if (rename_valid_i && (rename_arch_i != ARCH_ZERO) &&
                        (rename_arch_i == arch_reg_t'(arch))) begin
                        checkpoint_map_q[rob_index(checkpoint_branch_tag_i)][arch] <= rename_phys_i;
                    end else begin
                        checkpoint_map_q[rob_index(checkpoint_branch_tag_i)][arch] <= speculative_map_q[arch];
                    end
                end
            end

            speculative_map_q[ARCH_ZERO] <= PHYS_ZERO;
            committed_map_q[ARCH_ZERO] <= PHYS_ZERO;
        end
    end

endmodule
