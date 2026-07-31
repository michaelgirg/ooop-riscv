`timescale 1ns/1ps

module rob_tb;
    import rv32i_pkg::*;
    import ooo_pkg::*;

    localparam int CLK_PERIOD = 10;

    logic clk;
    logic rst;
    logic dispatch_valid;
    renamed_uop_t dispatch_uop;
    logic dispatch_ready;
    rob_tag_t dispatch_tag;
    result_bus_t result;
    recovery_event_t recovery;
    logic commit_valid;
    rob_commit_t commit;
    logic commit_ready;
    rob_tag_t head_tag;
    logic empty;
    logic full;
    logic [ROB_INDEX_BITS:0] count;
    int errors;

    rob dut (
        .clk             (clk),
        .rst             (rst),
        .dispatch_valid_i(dispatch_valid),
        .dispatch_uop_i  (dispatch_uop),
        .dispatch_ready_o(dispatch_ready),
        .dispatch_tag_o  (dispatch_tag),
        .result_i        (result),
        .recovery_i      (recovery),
        .commit_valid_o  (commit_valid),
        .commit_o        (commit),
        .commit_ready_i  (commit_ready),
        .head_tag_o      (head_tag),
        .empty_o         (empty),
        .full_o          (full),
        .count_o         (count)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    function automatic renamed_uop_t make_uop(
        input rob_tag_t tag,
        input int sequence_number
    );
        renamed_uop_t uop;
        uop = RENAMED_UOP_EMPTY;
        uop.decoded.valid = 1'b1;
        uop.decoded.pc = sequence_number * 4;
        uop.decoded.instruction = 32'h0010_0093 + sequence_number;
        uop.decoded.uop_class = UOP_ALU;
        uop.decoded.writes_rd = 1'b1;
        uop.decoded.rd_arch = arch_reg_t'((sequence_number % 31) + 1);
        uop.rob_tag = tag;
        uop.rd_phys = phys_reg_t'((sequence_number % 31) + 32);
        uop.stale_rd_phys = phys_reg_t'((sequence_number % 31) + 1);
        uop.has_phys_destination = 1'b1;
        return uop;
    endfunction

    task automatic clear_inputs();
        dispatch_valid = 1'b0;
        dispatch_uop = RENAMED_UOP_EMPTY;
        result = COMPLETION_EMPTY;
        recovery = RECOVERY_EVENT_NONE;
        commit_ready = 1'b0;
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

    task automatic check_int(
        input int actual,
        input int expected,
        input string name
    );
        if (actual != expected) begin
            $error("%s: expected %0d, got %0d", name, expected, actual);
            errors++;
        end
    endtask

    task automatic check_tag(
        input rob_tag_t actual,
        input rob_tag_t expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected generation=%0d position=%0d, got generation=%0d position=%0d",
                   name, expected.generation, expected.position,
                   actual.generation, actual.position);
            errors++;
        end
    endtask

    task automatic dispatch_one(
        input int sequence_number,
        output rob_tag_t allocated_tag
    );
        @(negedge clk);
        if (!dispatch_ready) begin
            $error("ROB was not ready for sequence %0d", sequence_number);
            errors++;
        end

        allocated_tag = dispatch_tag;
        dispatch_uop = make_uop(allocated_tag, sequence_number);
        dispatch_valid = 1'b1;
        @(posedge clk);
        #1;
        dispatch_valid = 1'b0;
        dispatch_uop = RENAMED_UOP_EMPTY;
    endtask

    task automatic send_completion(
        input rob_tag_t tag,
        input logic [31:0] value,
        input logic make_exception
    );
        @(negedge clk);
        result = COMPLETION_EMPTY;
        result.valid = 1'b1;
        result.rob_tag = tag;
        result.writes_phys = 1'b1;
        result.rd_phys = phys_reg_t'(rob_index(tag) + 32);
        result.result = value;
        result.memory_address_valid = 1'b1;
        result.memory_address = 32'h1000_0000 + value;
        result.store_data = value ^ 32'hffff_ffff;
        result.exception_valid = make_exception;
        result.exception_cause = EXC_LOAD_ACCESS_FAULT;
        result.exception_value = 32'hbad0_0000 | value;
        @(posedge clk);
        #1;
        result = COMPLETION_EMPTY;
    endtask

    task automatic retire_head(input rob_tag_t expected_tag);
        @(negedge clk);
        check_bit(commit_valid, 1'b1, "commit valid before retirement");
        check_tag(commit.rob_tag, expected_tag, "commit tag before retirement");
        commit_ready = 1'b1;
        @(posedge clk);
        #1;
        commit_ready = 1'b0;
    endtask

    task automatic send_recovery(
        input rob_tag_t branch_tag,
        input logic [31:0] redirect_pc
    );
        @(negedge clk);
        recovery = RECOVERY_EVENT_NONE;
        recovery.valid = 1'b1;
        recovery.branch_tag = branch_tag;
        recovery.redirect_pc = redirect_pc;
        @(posedge clk);
        #1;
        recovery = RECOVERY_EVENT_NONE;
    endtask

    initial begin
        rob_tag_t tag_0;
        rob_tag_t tag_1;
        rob_tag_t tag_2;
        rob_tag_t tag_3;
        rob_tag_t expected_tag;
        rob_tag_t stale_tag;
        rob_tag_t recovered_tag;
        rob_tag_t fill_tags [0:ROB_ENTRIES-1];
        rob_commit_t held_commit;

        errors = 0;
        rst = 1'b0;
        reset_dut();

        check_bit(empty, 1'b1, "empty after reset");
        check_bit(full, 1'b0, "not full after reset");
        check_bit(dispatch_ready, 1'b1, "ready after reset");
        check_int(count, 0, "count after reset");
        expected_tag = '0;
        check_tag(dispatch_tag, expected_tag, "first dispatch tag");
        check_tag(head_tag, expected_tag, "head tag after reset");

        // Out-of-order completion cannot bypass the incomplete head.
        dispatch_one(0, tag_0);
        dispatch_one(1, tag_1);
        dispatch_one(2, tag_2);
        send_completion(tag_1, 32'h1111_0001, 1'b0);
        check_bit(commit_valid, 1'b0, "younger completion blocked by head");

        send_completion(tag_0, 32'h1111_0000, 1'b0);
        check_bit(commit_valid, 1'b1, "completed head becomes committable");
        check_tag(commit.rob_tag, tag_0, "first completed head tag");
        if (commit.result !== 32'h1111_0000) begin
            $error("First commit result mismatch");
            errors++;
        end

        // Back-pressure must hold the complete head payload stable.
        held_commit = commit;
        repeat (2) begin
            @(posedge clk);
            #1;
            if ((commit_valid !== 1'b1) || (commit !== held_commit)) begin
                $error("Commit payload changed while commit_ready was low");
                errors++;
            end
        end

        retire_head(tag_0);
        check_tag(head_tag, tag_1, "head after first retirement");
        retire_head(tag_1);
        check_bit(commit_valid, 1'b0, "third entry still incomplete");
        send_completion(tag_2, 32'h1111_0002, 1'b1);
        check_bit(commit.exception_valid, 1'b1, "completion exception recorded");
        retire_head(tag_2);
        check_bit(empty, 1'b1, "empty after three retirements");

        // A completion with the right slot but wrong generation is ignored.
        dispatch_one(3, tag_3);
        stale_tag = tag_3;
        stale_tag.generation = tag_3.generation + 1'b1;
        send_completion(stale_tag, 32'hdead_0003, 1'b0);
        check_bit(commit_valid, 1'b0, "wrong-generation completion ignored");
        send_completion(tag_3, 32'h1111_0003, 1'b0);
        retire_head(tag_3);

        // Normal allocation advances position and changes generation when the
        // complete circular position space wraps.
        reset_dut();
        expected_tag = '0;
        for (int sequence_number = 0;
             sequence_number < (2 * ROB_ENTRIES + 3);
             sequence_number++) begin
            dispatch_one(sequence_number, tag_0);
            check_tag(tag_0, expected_tag,
                      $sformatf("sequential tag %0d", sequence_number));
            send_completion(tag_0, 32'h2000_0000 + sequence_number, 1'b0);
            retire_head(tag_0);
            expected_tag = rob_next_tag(expected_tag);
        end

        // Fill every entry and verify allocation back-pressure.
        reset_dut();
        for (int index = 0; index < ROB_ENTRIES; index++)
            dispatch_one(index, fill_tags[index]);

        check_bit(full, 1'b1, "full after ROB_ENTRIES dispatches");
        check_bit(dispatch_ready, 1'b0, "dispatch blocked while full");
        check_int(count, ROB_ENTRIES, "full count");

        @(negedge clk);
        dispatch_valid = 1'b1;
        dispatch_uop = make_uop(dispatch_tag, 99);
        @(posedge clk);
        #1;
        dispatch_valid = 1'b0;
        check_int(count, ROB_ENTRIES, "full ROB rejects dispatch");

        for (int index = 0; index < ROB_ENTRIES; index++) begin
            send_completion(fill_tags[index], 32'h3000_0000 + index, 1'b0);
            retire_head(fill_tags[index]);
        end
        check_bit(empty, 1'b1, "empty after draining full ROB");

        // Recovery preserves older entries and the branch, removes younger
        // entries, and changes generation before reusing a squashed slot.
        reset_dut();
        dispatch_one(10, tag_0); // older
        dispatch_one(11, tag_1); // resolving branch
        dispatch_one(12, tag_2); // younger, later squashed
        dispatch_one(13, tag_3); // younger, later squashed
        send_completion(tag_0, 32'h4000_0000, 1'b0);
        send_completion(tag_1, 32'h4000_0001, 1'b0);
        send_completion(tag_3, 32'h4000_0003, 1'b0);

        stale_tag = tag_2;
        send_recovery(tag_1, 32'h0000_0080);
        check_int(count, 2, "count after selective recovery");
        recovered_tag = rob_recovery_next_tag(tag_1);
        check_tag(dispatch_tag, recovered_tag, "post-recovery dispatch tag");

        // The old tag_2 result targets the same slot but an old generation.
        dispatch_one(20, tag_2);
        check_tag(tag_2, recovered_tag, "reallocated tag generation");
        send_completion(stale_tag, 32'hdead_0002, 1'b0);
        send_completion(tag_2, 32'h4000_0020, 1'b0);

        retire_head(tag_0);
        retire_head(tag_1);
        check_bit(commit_valid, 1'b1, "new post-recovery entry completes");
        if (commit.result !== 32'h4000_0020) begin
            $error("Stale completion corrupted recovered ROB entry");
            errors++;
        end
        retire_head(tag_2);
        check_bit(empty, 1'b1, "empty after recovery sequence");

        if (errors == 0)
            $display("PASS: rob_tb");
        else
            $fatal(1, "FAIL: rob_tb had %0d errors", errors);

        $finish;
    end

endmodule
