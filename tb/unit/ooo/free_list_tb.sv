`timescale 1ns/1ps

module free_list_tb;
    import ooo_pkg::*;

    localparam int CLK_PERIOD = 10;
    localparam int RANDOM_CYCLES = 500;

    logic clk;
    logic rst;
    logic allocate_valid;
    phys_reg_t allocate_phys;
    logic allocate_ready;
    logic release_valid;
    phys_reg_t release_phys;
    logic checkpoint_save_valid;
    rob_tag_t checkpoint_branch_tag;
    logic recover_valid;
    rob_tag_t recover_branch_tag;
    logic rebuild_valid;
    phys_reg_mask_t rebuild_in_use;
    logic empty;
    logic full;

    phys_reg_t model_queue[$];
    phys_reg_t checkpoint_queue[$];
    phys_reg_t releases_after_checkpoint[$];
    rob_tag_t saved_checkpoint_tag;
    logic checkpoint_active;
    int errors;

    free_list dut (
        .clk                    (clk),
        .rst                    (rst),
        .allocate_valid_o       (allocate_valid),
        .allocate_phys_o        (allocate_phys),
        .allocate_ready_i       (allocate_ready),
        .release_valid_i        (release_valid),
        .release_phys_i         (release_phys),
        .checkpoint_save_valid_i(checkpoint_save_valid),
        .checkpoint_branch_tag_i(checkpoint_branch_tag),
        .recover_valid_i        (recover_valid),
        .recover_branch_tag_i   (recover_branch_tag),
        .rebuild_valid_i        (rebuild_valid),
        .rebuild_in_use_i       (rebuild_in_use),
        .empty_o                (empty),
        .full_o                 (full)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    function automatic rob_tag_t make_tag(
        input int generation,
        input int position
    );
        rob_tag_t tag;
        tag = '0;
        tag.generation = generation[ROB_GENERATION_BITS-1:0];
        tag.position = position[ROB_POSITION_BITS-1:0];
        return tag;
    endfunction

    task automatic clear_inputs();
        allocate_ready = 1'b0;
        release_valid = 1'b0;
        release_phys = PHYS_ZERO;
        checkpoint_save_valid = 1'b0;
        checkpoint_branch_tag = '0;
        recover_valid = 1'b0;
        recover_branch_tag = '0;
        rebuild_valid = 1'b0;
        rebuild_in_use = '0;
    endtask

    task automatic initialize_model();
        model_queue.delete();
        checkpoint_queue.delete();
        releases_after_checkpoint.delete();
        checkpoint_active = 1'b0;

        for (int tag = ARCH_REG_COUNT; tag < PHYS_REG_COUNT; tag++)
            model_queue.push_back(phys_reg_t'(tag));
    endtask

    task automatic reset_dut();
        clear_inputs();
        initialize_model();
        rst = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        #1;
    endtask

    task automatic check_outputs(input string name);
        logic expected_valid;
        logic expected_empty;
        logic expected_full;

        expected_valid = (model_queue.size() != 0);
        expected_empty = (model_queue.size() == 0);
        expected_full = (model_queue.size() == FREE_LIST_ENTRIES);

        if (allocate_valid !== expected_valid) begin
            $error("%s allocate_valid: expected %b, got %b",
                   name, expected_valid, allocate_valid);
            errors++;
        end
        if (empty !== expected_empty) begin
            $error("%s empty: expected %b, got %b", name, expected_empty, empty);
            errors++;
        end
        if (full !== expected_full) begin
            $error("%s full: expected %b, got %b", name, expected_full, full);
            errors++;
        end
        if (expected_valid && (allocate_phys !== model_queue[0])) begin
            $error("%s next tag: expected p%0d, got p%0d",
                   name, model_queue[0], allocate_phys);
            errors++;
        end
    endtask

    task automatic drive_cycle(
        input logic take_allocation,
        input logic return_valid,
        input phys_reg_t return_tag,
        input logic save_checkpoint,
        input rob_tag_t save_tag,
        input logic recover_checkpoint,
        input rob_tag_t recovery_tag,
        input logic rebuild,
        input phys_reg_mask_t in_use_mask
    );
        logic allocation_fire;

        @(negedge clk);
        allocate_ready = take_allocation;
        release_valid = return_valid;
        release_phys = return_tag;
        checkpoint_save_valid = save_checkpoint;
        checkpoint_branch_tag = save_tag;
        recover_valid = recover_checkpoint;
        recover_branch_tag = recovery_tag;
        rebuild_valid = rebuild;
        rebuild_in_use = in_use_mask;

        allocation_fire = take_allocation && (model_queue.size() != 0);
        @(posedge clk);

        if (rebuild) begin
            model_queue.delete();
            for (int tag = 1; tag < PHYS_REG_COUNT; tag++) begin
                if (!in_use_mask[tag])
                    model_queue.push_back(phys_reg_t'(tag));
            end
            checkpoint_active = 1'b0;
            checkpoint_queue.delete();
            releases_after_checkpoint.delete();
        end
        else if (recover_checkpoint) begin
            if (!checkpoint_active || (recovery_tag !== saved_checkpoint_tag)) begin
                $error("Recovery used a checkpoint not saved by the model");
                errors++;
            end
            else begin
                model_queue = checkpoint_queue;
                foreach (releases_after_checkpoint[index])
                    model_queue.push_back(releases_after_checkpoint[index]);
            end
            checkpoint_active = 1'b0;
        end
        else begin
            if (allocation_fire) void'(model_queue.pop_front());

            // p0 is never a legal free-list entry.
            if (return_valid && (return_tag != PHYS_ZERO)) begin
                model_queue.push_back(return_tag);
                if (checkpoint_active && !save_checkpoint)
                    releases_after_checkpoint.push_back(return_tag);
            end

            // Save after the branch's same-cycle allocation and any older
            // retirement release have been applied.
            if (save_checkpoint) begin
                checkpoint_queue = model_queue;
                releases_after_checkpoint.delete();
                saved_checkpoint_tag = save_tag;
                checkpoint_active = 1'b1;
            end
        end

        #1;
        clear_inputs();
    endtask

    function automatic logic model_contains(input phys_reg_t tag);
        foreach (model_queue[index]) begin
            if (model_queue[index] == tag) return 1'b1;
        end
        return 1'b0;
    endfunction

    initial begin
        phys_reg_mask_t committed_mask;
        phys_reg_t allocated_tag;
        phys_reg_t allocated_pool[$];
        logic do_allocate;
        logic do_release;
        int release_index;

        errors = 0;
        rst = 1'b0;
        reset_dut();
        check_outputs("reset");

        // Back-pressure must keep the offered head tag stable.
        allocated_tag = allocate_phys;
        repeat (3) begin
            drive_cycle(1'b0, 1'b0, PHYS_ZERO,
                        1'b0, '0, 1'b0, '0, 1'b0, '0);
            check_outputs("allocation back-pressure");
            if (allocate_phys !== allocated_tag) begin
                $error("Allocation tag changed while ready was low");
                errors++;
            end
        end

        // Allocate p32-p35. The p35 cycle saves the branch checkpoint after
        // that allocation, making p36 the first recoverable younger tag.
        for (int tag = 32; tag <= 34; tag++) begin
            check_outputs($sformatf("before allocating p%0d", tag));
            drive_cycle(1'b1, 1'b0, PHYS_ZERO,
                        1'b0, '0, 1'b0, '0, 1'b0, '0);
        end

        saved_checkpoint_tag = make_tag(0, 7);
        drive_cycle(1'b1, 1'b0, PHYS_ZERO,
                    1'b1, saved_checkpoint_tag,
                    1'b0, '0, 1'b0, '0);
        check_outputs("checkpoint after p35");

        drive_cycle(1'b1, 1'b0, PHYS_ZERO,
                    1'b0, '0, 1'b0, '0, 1'b0, '0);
        drive_cycle(1'b1, 1'b1, phys_reg_t'(5),
                    1'b0, '0, 1'b0, '0, 1'b0, '0);
        drive_cycle(1'b0, 1'b0, PHYS_ZERO,
                    1'b0, '0, 1'b1, saved_checkpoint_tag, 1'b0, '0);
        check_outputs("branch recovery");

        if (allocate_phys !== phys_reg_t'(36)) begin
            $error("Recovery did not return younger allocation p36 first");
            errors++;
        end

        // p0 releases are ignored.
        drive_cycle(1'b0, 1'b1, PHYS_ZERO,
                    1'b0, '0, 1'b0, '0, 1'b0, '0);
        check_outputs("ignored p0 release");

        // Precise-trap rebuild uses the committed-map in-use mask and produces
        // a deterministic ascending free-register order.
        committed_mask = '0;
        for (int tag = 0; tag < ARCH_REG_COUNT; tag++)
            committed_mask[tag] = 1'b1;
        committed_mask[40] = 1'b1;
        committed_mask[41] = 1'b1;
        committed_mask[30] = 1'b0;
        committed_mask[31] = 1'b0;

        drive_cycle(1'b0, 1'b0, PHYS_ZERO,
                    1'b0, '0, 1'b0, '0,
                    1'b1, committed_mask);
        check_outputs("committed-state rebuild");
        if (allocate_phys !== phys_reg_t'(30)) begin
            $error("Rebuild expected p30 first, got p%0d", allocate_phys);
            errors++;
        end

        // Start fresh for randomized queue checking without recovery.
        reset_dut();
        allocated_pool.delete();

        for (int cycle = 0; cycle < RANDOM_CYCLES; cycle++) begin
            do_allocate = (model_queue.size() != 0) &&
                          ($urandom_range(0, 1) == 1);
            do_release = (allocated_pool.size() != 0) &&
                         ($urandom_range(0, 1) == 1);
            release_index = 0;
            allocated_tag = PHYS_ZERO;

            if (do_allocate) allocated_tag = model_queue[0];
            if (do_release) begin
                release_index = $urandom_range(0, allocated_pool.size() - 1);
                release_phys = allocated_pool[release_index];
            end

            drive_cycle(do_allocate, do_release,
                        do_release ? allocated_pool[release_index] : PHYS_ZERO,
                        1'b0, '0, 1'b0, '0, 1'b0, '0);

            if (do_allocate) allocated_pool.push_back(allocated_tag);
            if (do_release) allocated_pool.delete(release_index);

            check_outputs($sformatf("random cycle %0d", cycle));

            // No duplicate or p0 entry may appear in the free queue model.
            if (model_contains(PHYS_ZERO)) begin
                $error("p0 appeared in the free-list model");
                errors++;
            end
            for (int first = 0; first < model_queue.size(); first++) begin
                for (int second = first + 1;
                     second < model_queue.size(); second++) begin
                    if (model_queue[first] == model_queue[second]) begin
                        $error("Duplicate p%0d in free-list model",
                               model_queue[first]);
                        errors++;
                    end
                end
            end
        end

        if (errors == 0)
            $display("PASS: free_list_tb (%0d random cycles)", RANDOM_CYCLES);
        else
            $fatal(1, "FAIL: free_list_tb had %0d errors", errors);

        $finish;
    end

endmodule
