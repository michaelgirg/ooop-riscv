`timescale 1ns/1ps

module rename_map_tb;
    import ooo_pkg::*;

    localparam int CLK_PERIOD = 10;
    localparam int RANDOM_CYCLES = 300;
    localparam int ROB_TAG_VALUES = 1 << ROB_TAG_BITS;

    logic clk;
    logic rst;
    arch_reg_t source_1_arch;
    arch_reg_t source_2_arch;
    arch_reg_t destination_arch;
    phys_reg_t source_1_phys;
    phys_reg_t source_2_phys;
    phys_reg_t stale_destination_phys;
    phys_reg_mask_t committed_phys_in_use;
    logic rename_valid;
    arch_reg_t rename_arch;
    phys_reg_t rename_phys;
    logic commit_valid;
    arch_reg_t commit_arch;
    phys_reg_t commit_phys;
    logic checkpoint_save_valid;
    rob_tag_t checkpoint_branch_tag;
    logic recover_valid;
    rob_tag_t recover_branch_tag;
    logic restore_committed;

    phys_reg_t speculative_model [0:ARCH_REG_COUNT-1];
    phys_reg_t committed_model [0:ARCH_REG_COUNT-1];
    phys_reg_t checkpoint_model [0:ROB_TAG_VALUES-1][0:ARCH_REG_COUNT-1];
    logic checkpoint_valid_model [0:ROB_TAG_VALUES-1];
    int errors;

    rename_map dut (
        .clk                         (clk),
        .rst                         (rst),
        .source_1_arch_i             (source_1_arch),
        .source_2_arch_i             (source_2_arch),
        .destination_arch_i          (destination_arch),
        .source_1_phys_o             (source_1_phys),
        .source_2_phys_o             (source_2_phys),
        .stale_destination_phys_o    (stale_destination_phys),
        .committed_phys_in_use_o     (committed_phys_in_use),
        .rename_valid_i              (rename_valid),
        .rename_arch_i               (rename_arch),
        .rename_phys_i               (rename_phys),
        .commit_valid_i              (commit_valid),
        .commit_arch_i               (commit_arch),
        .commit_phys_i               (commit_phys),
        .checkpoint_save_valid_i     (checkpoint_save_valid),
        .checkpoint_branch_tag_i     (checkpoint_branch_tag),
        .recover_valid_i             (recover_valid),
        .recover_branch_tag_i        (recover_branch_tag),
        .restore_committed_i         (restore_committed)
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

    function automatic phys_reg_mask_t model_committed_mask();
        phys_reg_mask_t mask;
        mask = '0;
        for (int arch = 0; arch < ARCH_REG_COUNT; arch++)
            mask[committed_model[arch]] = 1'b1;
        return mask;
    endfunction

    task automatic clear_inputs();
        source_1_arch = ARCH_ZERO;
        source_2_arch = ARCH_ZERO;
        destination_arch = ARCH_ZERO;
        rename_valid = 1'b0;
        rename_arch = ARCH_ZERO;
        rename_phys = PHYS_ZERO;
        commit_valid = 1'b0;
        commit_arch = ARCH_ZERO;
        commit_phys = PHYS_ZERO;
        checkpoint_save_valid = 1'b0;
        checkpoint_branch_tag = '0;
        recover_valid = 1'b0;
        recover_branch_tag = '0;
        restore_committed = 1'b0;
    endtask

    task automatic initialize_model();
        for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin
            speculative_model[arch] = phys_reg_t'(arch);
            committed_model[arch] = phys_reg_t'(arch);
        end

        for (int tag = 0; tag < ROB_TAG_VALUES; tag++)
            checkpoint_valid_model[tag] = 1'b0;
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

    task automatic check_tag(
        input phys_reg_t actual,
        input phys_reg_t expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected p%0d, got p%0d", name, expected, actual);
            errors++;
        end
    endtask

    task automatic check_all_maps(input string name);
        phys_reg_mask_t expected_mask;

        for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin
            source_1_arch = arch_reg_t'(arch);
            source_2_arch = arch_reg_t'((arch + 1) % ARCH_REG_COUNT);
            destination_arch = arch_reg_t'(arch);
            #1;

            check_tag(source_1_phys, speculative_model[arch],
                      $sformatf("%s rs1 x%0d", name, arch));
            check_tag(source_2_phys,
                      speculative_model[(arch + 1) % ARCH_REG_COUNT],
                      $sformatf("%s rs2 x%0d", name,
                                (arch + 1) % ARCH_REG_COUNT));
            check_tag(stale_destination_phys, speculative_model[arch],
                      $sformatf("%s stale x%0d", name, arch));
        end

        expected_mask = model_committed_mask();
        if (committed_phys_in_use !== expected_mask) begin
            $error("%s committed mask: expected %016h, got %016h",
                   name, expected_mask, committed_phys_in_use);
            errors++;
        end
    endtask

    task automatic drive_controls(
        input logic do_rename,
        input arch_reg_t rename_arch_value,
        input phys_reg_t rename_phys_value,
        input logic do_commit,
        input arch_reg_t commit_arch_value,
        input phys_reg_t commit_phys_value,
        input logic do_save,
        input rob_tag_t save_tag,
        input logic do_recover,
        input rob_tag_t recovery_tag,
        input logic do_restore
    );
        @(negedge clk);
        rename_valid = do_rename;
        rename_arch = rename_arch_value;
        rename_phys = rename_phys_value;
        commit_valid = do_commit;
        commit_arch = commit_arch_value;
        commit_phys = commit_phys_value;
        checkpoint_save_valid = do_save;
        checkpoint_branch_tag = save_tag;
        recover_valid = do_recover;
        recover_branch_tag = recovery_tag;
        restore_committed = do_restore;

        @(posedge clk);

        if (do_restore) begin
            for (int arch = 0; arch < ARCH_REG_COUNT; arch++)
                speculative_model[arch] = committed_model[arch];
        end
        else if (do_recover) begin
            if (!checkpoint_valid_model[int'(recovery_tag)]) begin
                $error("Test attempted recovery from an unsaved checkpoint");
                errors++;
            end
            else begin
                for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin
                    speculative_model[arch] =
                        checkpoint_model[int'(recovery_tag)][arch];
                end
            end
        end
        else begin
            if (do_commit && (commit_arch_value != ARCH_ZERO))
                committed_model[commit_arch_value] = commit_phys_value;

            if (do_rename && (rename_arch_value != ARCH_ZERO))
                speculative_model[rename_arch_value] = rename_phys_value;

            // A branch checkpoint includes its own same-cycle destination.
            if (do_save) begin
                checkpoint_valid_model[int'(save_tag)] = 1'b1;
                for (int arch = 0; arch < ARCH_REG_COUNT; arch++) begin
                    checkpoint_model[int'(save_tag)][arch] =
                        speculative_model[arch];
                end
            end
        end

        speculative_model[0] = PHYS_ZERO;
        committed_model[0] = PHYS_ZERO;
        #1;
        clear_inputs();
    endtask

    initial begin
        int action;
        int random_arch_1;
        int random_arch_2;
        int random_phys_1;
        int random_phys_2;
        int random_tag_slot;
        rob_tag_t saved_tags [0:3];

        errors = 0;
        rst = 1'b0;
        reset_dut();
        check_all_maps("reset");

        // x0 ignores both speculative rename and commit updates.
        drive_controls(1'b1, ARCH_ZERO, phys_reg_t'(40),
                       1'b1, ARCH_ZERO, phys_reg_t'(41),
                       1'b0, '0, 1'b0, '0, 1'b0);
        check_all_maps("x0 protection");

        // Checkpoint saving and recovery, including a same-cycle branch rd.
        drive_controls(1'b1, arch_reg_t'(5), phys_reg_t'(40),
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b0, '0, 1'b0);

        saved_tags[0] = make_tag(0, 3);
        drive_controls(1'b1, arch_reg_t'(6), phys_reg_t'(41),
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b1, saved_tags[0], 1'b0, '0, 1'b0);

        drive_controls(1'b1, arch_reg_t'(6), phys_reg_t'(42),
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b0, '0, 1'b0);
        drive_controls(1'b1, arch_reg_t'(7), phys_reg_t'(43),
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b0, '0, 1'b0);
        drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b1, saved_tags[0], 1'b0);
        check_all_maps("branch checkpoint recovery");

        // Commit state must be externally testable through precise restore.
        drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b1, arch_reg_t'(8), phys_reg_t'(44),
                       1'b0, '0, 1'b0, '0, 1'b0);
        drive_controls(1'b1, arch_reg_t'(8), phys_reg_t'(45),
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b0, '0, 1'b0);
        drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b0, '0, 1'b1);
        check_all_maps("committed-state restore");

        // Retirement of an older writer and rename of a younger writer may
        // update the committed and speculative maps in the same cycle.
        drive_controls(1'b1, arch_reg_t'(9), phys_reg_t'(47),
                       1'b1, arch_reg_t'(9), phys_reg_t'(46),
                       1'b0, '0, 1'b0, '0, 1'b0);
        check_all_maps("simultaneous commit and rename");
        drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, ARCH_ZERO, PHYS_ZERO,
                       1'b0, '0, 1'b0, '0, 1'b1);
        check_all_maps("restore after simultaneous updates");

        // Randomized operations checked against complete speculative,
        // committed, and checkpoint shadow models.
        for (int index = 0; index < 4; index++)
            saved_tags[index] = make_tag(index % 3, index + 5);

        for (int cycle = 0; cycle < RANDOM_CYCLES; cycle++) begin
            action = $urandom_range(0, 6);
            random_arch_1 = $urandom_range(0, ARCH_REG_COUNT - 1);
            random_arch_2 = $urandom_range(0, ARCH_REG_COUNT - 1);
            random_phys_1 = $urandom_range(0, PHYS_REG_COUNT - 1);
            random_phys_2 = $urandom_range(0, PHYS_REG_COUNT - 1);
            random_tag_slot = $urandom_range(0, 3);

            case (action)
                0: drive_controls(1'b1, arch_reg_t'(random_arch_1),
                                  phys_reg_t'(random_phys_1),
                                  1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b0, '0, 1'b0, '0, 1'b0);
                1: drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b1, arch_reg_t'(random_arch_1),
                                  phys_reg_t'(random_phys_1),
                                  1'b0, '0, 1'b0, '0, 1'b0);
                2: drive_controls(1'b1, arch_reg_t'(random_arch_1),
                                  phys_reg_t'(random_phys_1),
                                  1'b1, arch_reg_t'(random_arch_2),
                                  phys_reg_t'(random_phys_2),
                                  1'b0, '0, 1'b0, '0, 1'b0);
                3: drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b1, saved_tags[random_tag_slot],
                                  1'b0, '0, 1'b0);
                4: drive_controls(1'b1, arch_reg_t'(random_arch_1),
                                  phys_reg_t'(random_phys_1),
                                  1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b1, saved_tags[random_tag_slot],
                                  1'b0, '0, 1'b0);
                5: begin
                    if (checkpoint_valid_model[int'(saved_tags[random_tag_slot])])
                        drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                                       1'b0, ARCH_ZERO, PHYS_ZERO,
                                       1'b0, '0, 1'b1,
                                       saved_tags[random_tag_slot], 1'b0);
                end
                6: drive_controls(1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b0, ARCH_ZERO, PHYS_ZERO,
                                  1'b0, '0, 1'b0, '0, 1'b1);
            endcase

            check_all_maps($sformatf("random cycle %0d", cycle));
        end

        if (errors == 0)
            $display("PASS: rename_map_tb (%0d random cycles)", RANDOM_CYCLES);
        else
            $fatal(1, "FAIL: rename_map_tb had %0d errors", errors);

        $finish;
    end

endmodule
