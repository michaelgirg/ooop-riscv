import ooo_pkg::*;

// Circular free list for physical destination registers.
//
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
    input var rob_tag_t checkpoint_branch_tag_i,

    // Keep retirement-side releases, but undo allocations younger than the
    // recovering branch.
    input logic     recover_valid_i,
    input var rob_tag_t recover_branch_tag_i,

    // A precise trap rebuilds the free queue from the physical registers not
    // referenced by the committed rename map. Rebuild has priority over normal
    // allocation, release, checkpoint, and branch-recovery activity.
    input logic           rebuild_valid_i,
    input phys_reg_mask_t rebuild_in_use_i,

    output logic empty_o,
    // full_o means all FREE_LIST_ENTRIES tags are currently available.
    output logic full_o
);

    phys_reg_t free_queue_q [0:FREE_LIST_ENTRIES-1];
    free_list_ptr_t head_q;
    free_list_ptr_t tail_q;
    logic [FREE_LIST_INDEX_BITS:0] count_q;

    free_list_ptr_t checkpoint_head_q [0:BRANCH_CHECKPOINTS-1];
    rob_tag_t       checkpoint_tag_q [0:BRANCH_CHECKPOINTS-1];
    logic           checkpoint_valid_q [0:BRANCH_CHECKPOINTS-1];

    logic allocation_fire;
    logic release_fire;

    always_comb begin
        // Rebuild/recovery own the state update, so do not advertise an
        // allocation transfer that those priority paths would ignore.
        allocate_valid_o = (count_q != 0) && !rst && !rebuild_valid_i &&
                           !recover_valid_i;
        allocate_phys_o = allocate_valid_o
                          ? free_queue_q[head_q[FREE_LIST_INDEX_BITS-1:0]]
                          : PHYS_ZERO;
        empty_o = (count_q == 0);
        full_o = (count_q == FREE_LIST_ENTRIES);

        allocation_fire = allocate_valid_o && allocate_ready_i;
        release_fire = release_valid_i && (release_phys_i != PHYS_ZERO) &&
                       ((count_q < FREE_LIST_ENTRIES) || allocation_fire);
    end

    always_ff @(posedge clk) begin : free_list_state
        integer rebuilt_count;
        free_list_ptr_t next_head;
        free_list_ptr_t next_tail;

        if (rst) begin
            for (int index = 0; index < FREE_LIST_ENTRIES; index++)
                free_queue_q[index] <= phys_reg_t'(ARCH_REG_COUNT + index);

            head_q <= '0;
            tail_q <= free_list_ptr_t'(FREE_LIST_ENTRIES);
            count_q <= FREE_LIST_ENTRIES;

            for (int slot = 0; slot < BRANCH_CHECKPOINTS; slot++) begin
                checkpoint_head_q[slot] <= '0;
                checkpoint_tag_q[slot] <= '0;
                checkpoint_valid_q[slot] <= 1'b0;
            end
        end else if (rebuild_valid_i) begin
            // Reconstruct a deterministic queue from committed architectural
            // state. A valid committed map leaves exactly FREE_LIST_ENTRIES
            // physical registers unused.
            rebuilt_count = 0;
            for (int tag = 1; tag < PHYS_REG_COUNT; tag++) begin
                if (!rebuild_in_use_i[tag] &&
                    (rebuilt_count < FREE_LIST_ENTRIES)) begin
                    free_queue_q[rebuilt_count] <= phys_reg_t'(tag);
                    rebuilt_count = rebuilt_count + 1;
                end
            end

            head_q <= '0;
            tail_q <= free_list_ptr_t'(rebuilt_count);
            count_q <= rebuilt_count;

            for (int slot = 0; slot < BRANCH_CHECKPOINTS; slot++)
                checkpoint_valid_q[slot] <= 1'b0;
        end else if (recover_valid_i) begin
            if (checkpoint_valid_q[rob_index(recover_branch_tag_i)] &&
                (checkpoint_tag_q[rob_index(recover_branch_tag_i)] ==
                 recover_branch_tag_i)) begin
                head_q <= checkpoint_head_q[rob_index(recover_branch_tag_i)];
                count_q <= tail_q -
                           checkpoint_head_q[rob_index(recover_branch_tag_i)];
                checkpoint_valid_q[rob_index(recover_branch_tag_i)] <= 1'b0;
            end
        end else begin
            next_head = head_q + free_list_ptr_t'(allocation_fire);
            next_tail = tail_q + free_list_ptr_t'(release_fire);

            if (release_fire) begin
                free_queue_q[tail_q[FREE_LIST_INDEX_BITS-1:0]] <=
                    release_phys_i;
            end

            head_q <= next_head;
            tail_q <= next_tail;
            case ({release_fire, allocation_fire})
                2'b01: count_q <= count_q - 1'b1;
                2'b10: count_q <= count_q + 1'b1;
                default: count_q <= count_q;
            endcase

            // The checkpoint sees the queue after the branch's allocation and
            // any same-cycle release from an older retiring instruction.
            if (checkpoint_save_valid_i) begin
                checkpoint_head_q[rob_index(checkpoint_branch_tag_i)] <=
                    next_head;
                checkpoint_tag_q[rob_index(checkpoint_branch_tag_i)] <=
                    checkpoint_branch_tag_i;
                checkpoint_valid_q[rob_index(checkpoint_branch_tag_i)] <= 1'b1;
            end
        end
    end

endmodule
