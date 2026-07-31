`timescale 1ns/1ps

module physical_regfile_tb;
    import ooo_pkg::*;

    localparam int CLK_PERIOD = 10;
    localparam int RANDOM_CYCLES = 500;

    logic clk;
    logic rst;
    phys_reg_t source_1_tag;
    phys_reg_t source_2_tag;
    logic [31:0] source_1_value;
    logic [31:0] source_2_value;
    logic source_1_ready;
    logic source_2_ready;
    logic allocate_valid;
    phys_reg_t allocate_tag;
    result_bus_t result;

    logic [31:0] expected_value [0:PHYS_REG_COUNT-1];
    logic expected_ready [0:PHYS_REG_COUNT-1];
    int errors;

    physical_regfile dut (
        .clk             (clk),
        .rst             (rst),
        .source_1_tag_i  (source_1_tag),
        .source_2_tag_i  (source_2_tag),
        .source_1_value_o(source_1_value),
        .source_2_value_o(source_2_value),
        .source_1_ready_o(source_1_ready),
        .source_2_ready_o(source_2_ready),
        .allocate_valid_i(allocate_valid),
        .allocate_tag_i  (allocate_tag),
        .result_i        (result)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic clear_inputs();
        source_1_tag = PHYS_ZERO;
        source_2_tag = PHYS_ZERO;
        allocate_valid = 1'b0;
        allocate_tag = PHYS_ZERO;
        result = COMPLETION_EMPTY;
    endtask

    task automatic reset_dut();
        clear_inputs();
        rst = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        #1;
    endtask

    task automatic check_bit(
        input logic actual,
        input logic expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected %b, got %b", name, expected, actual);
            errors++;
        end
    endtask

    task automatic check_word(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected %08h, got %08h", name, expected, actual);
            errors++;
        end
    endtask

    task automatic check_sources(
        input phys_reg_t tag_1,
        input phys_reg_t tag_2,
        input string name
    );
        source_1_tag = tag_1;
        source_2_tag = tag_2;
        #1;

        check_word(source_1_value, expected_value[int'(tag_1)],
                   $sformatf("%s source 1 value", name));
        check_word(source_2_value, expected_value[int'(tag_2)],
                   $sformatf("%s source 2 value", name));
        check_bit(source_1_ready, expected_ready[int'(tag_1)],
                  $sformatf("%s source 1 ready", name));
        check_bit(source_2_ready, expected_ready[int'(tag_2)],
                  $sformatf("%s source 2 ready", name));
    endtask

    task automatic drive_cycle(
        input logic allocation_valid,
        input phys_reg_t allocation_tag,
        input logic writeback_valid,
        input logic writeback_enable,
        input phys_reg_t writeback_tag,
        input logic [31:0] writeback_value
    );
        @(negedge clk);
        allocate_valid = allocation_valid;
        allocate_tag = allocation_tag;
        result = COMPLETION_EMPTY;
        result.valid = writeback_valid;
        result.writes_phys = writeback_enable;
        result.rd_phys = writeback_tag;
        result.result = writeback_value;

        @(posedge clk);
        #1;
        allocate_valid = 1'b0;
        result = COMPLETION_EMPTY;
    endtask

    task automatic initialize_model();
        for (int tag = 0; tag < PHYS_REG_COUNT; tag++) begin
            expected_value[tag] = 32'b0;
            expected_ready[tag] = (tag < ARCH_REG_COUNT);
        end
        expected_ready[0] = 1'b1;
    endtask

    initial begin
        int allocation_index;
        int writeback_index;
        int read_index_1;
        int read_index_2;
        logic random_allocate;
        logic random_writeback;
        logic random_write_enable;
        logic [31:0] random_value;

        errors = 0;
        rst = 1'b0;
        initialize_model();
        reset_dut();

        // The initial architectural mappings p0-p31 hold ready zero values.
        for (int tag = 0; tag < ARCH_REG_COUNT; tag += 2) begin
            check_sources(phys_reg_t'(tag), phys_reg_t'(tag + 1),
                          $sformatf("reset tags %0d/%0d", tag, tag + 1));
        end

        // Allocation clears readiness; only a valid enabled result wakes it.
        drive_cycle(1'b1, phys_reg_t'(40), 1'b0, 1'b0, PHYS_ZERO, '0);
        expected_ready[40] = 1'b0;
        check_sources(phys_reg_t'(40), PHYS_ZERO, "allocated p40");

        drive_cycle(1'b0, PHYS_ZERO, 1'b1, 1'b0,
                    phys_reg_t'(40), 32'h1111_1111);
        check_sources(phys_reg_t'(40), PHYS_ZERO,
                      "writeback without writes_phys");

        drive_cycle(1'b0, PHYS_ZERO, 1'b1, 1'b1,
                    phys_reg_t'(41), 32'h2222_2222);
        check_sources(phys_reg_t'(40), PHYS_ZERO,
                      "unrelated writeback does not wake p40");

        drive_cycle(1'b0, PHYS_ZERO, 1'b1, 1'b1,
                    phys_reg_t'(40), 32'hcafe_0040);
        expected_value[40] = 32'hcafe_0040;
        expected_ready[40] = 1'b1;
        check_sources(phys_reg_t'(40), PHYS_ZERO, "matching writeback");

        // Allocation wins readiness when allocation and writeback target the
        // same tag. This prevents a reused destination from appearing ready.
        drive_cycle(1'b1, phys_reg_t'(40), 1'b1, 1'b1,
                    phys_reg_t'(40), 32'hdead_0040);
        expected_ready[40] = 1'b0;
        check_sources(phys_reg_t'(40), PHYS_ZERO,
                      "same-cycle reallocation priority");

        // p0 cannot be renamed, made not-ready, or overwritten.
        drive_cycle(1'b1, PHYS_ZERO, 1'b1, 1'b1,
                    PHYS_ZERO, 32'hffff_ffff);
        expected_value[0] = 32'b0;
        expected_ready[0] = 1'b1;
        check_sources(PHYS_ZERO, PHYS_ZERO, "p0 protection");

        // Reset again before randomized shadow-model checking.
        initialize_model();
        reset_dut();

        for (int cycle = 0; cycle < RANDOM_CYCLES; cycle++) begin
            random_allocate = $urandom_range(0, 1);
            random_writeback = $urandom_range(0, 1);
            random_write_enable = $urandom_range(0, 1);
            allocation_index = $urandom_range(0, PHYS_REG_COUNT - 1);
            writeback_index = $urandom_range(0, PHYS_REG_COUNT - 1);
            random_value = $urandom();

            drive_cycle(random_allocate, phys_reg_t'(allocation_index),
                        random_writeback, random_write_enable,
                        phys_reg_t'(writeback_index), random_value);

            if (random_writeback && random_write_enable &&
                (writeback_index != 0)) begin
                expected_value[writeback_index] = random_value;
                expected_ready[writeback_index] = 1'b1;
            end

            // Allocation has priority over writeback for the same tag.
            if (random_allocate && (allocation_index != 0))
                expected_ready[allocation_index] = 1'b0;

            expected_value[0] = 32'b0;
            expected_ready[0] = 1'b1;

            read_index_1 = $urandom_range(0, PHYS_REG_COUNT - 1);
            read_index_2 = $urandom_range(0, PHYS_REG_COUNT - 1);
            check_sources(phys_reg_t'(read_index_1),
                          phys_reg_t'(read_index_2),
                          $sformatf("random cycle %0d", cycle));
        end

        if (errors == 0)
            $display("PASS: physical_regfile_tb (%0d random cycles)",
                     RANDOM_CYCLES);
        else
            $fatal(1, "FAIL: physical_regfile_tb had %0d errors", errors);

        $finish;
    end

endmodule
