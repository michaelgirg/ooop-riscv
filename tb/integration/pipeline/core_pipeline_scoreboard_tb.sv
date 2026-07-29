`timescale 1ns/1ps

// Differential architectural scoreboard for the cached pipeline.
//
// The passing single-cycle RV32IM core and the cached pipeline execute the
// same directed program independently. The test compares every architectural
// register and the coherent memory image after both cores halt. It also checks
// that cache back-pressure holds the pipeline, every store request is issued
// once, and each static MUL/DIV instruction produces one issue pulse.
module core_pipeline_scoreboard_tb;
    import rv32i_pkg::*;

    localparam int CLK_PERIOD       = 10;
    localparam int MAX_CYCLES       = 2500;
    localparam int IMEM_WORDS       = 128;
    localparam int DMEM_WORDS       = 128;
    localparam int CACHE_LINE_WORDS = 4;
    localparam int DCACHE_NUM_SETS  = 2;
    localparam int DCACHE_NUM_WAYS  = 2;
    localparam int EXPECTED_RETIRES = 54;
    localparam int EXPECTED_STORES  = 4;
    localparam int EXPECTED_MULDIV  = 8;
    localparam int EXPECTED_DACCESS = 11;

    localparam int LINE_BYTES       = CACHE_LINE_WORDS * 4;
    localparam int LINE_OFFSET_BITS = $clog2(LINE_BYTES);
    localparam int SET_INDEX_BITS   = $clog2(DCACHE_NUM_SETS);
    localparam int TAG_BITS         = 32 - LINE_OFFSET_BITS - SET_INDEX_BITS;

    logic clk;
    logic rst;

    logic [31:0] pipeline_pc;
    logic [31:0] pipeline_instruction;
    logic pipeline_halted;
    logic pipeline_illegal;
    logic pipeline_ifault;
    logic pipeline_dfault;

    logic [31:0] reference_pc;
    logic [31:0] reference_instruction;
    logic reference_halted;
    logic reference_illegal;
    logic reference_ifault;
    logic reference_dfault;

    logic [31:0] instruction_image [0:IMEM_WORDS-1];
    int unsigned next_word;
    int errors;
    int elapsed_cycles;

    int store_requests;
    int store_responses;
    int retired_stores;
    int muldiv_issues;
    int retired_muldiv;
    int store_issue_by_word [0:IMEM_WORDS-1];
    int muldiv_issue_by_word [0:IMEM_WORDS-1];

    logic expect_mem_hold;
    logic [31:0] held_pc;
    id_ex_t held_id_ex;
    ex_mem_t held_ex_mem;

    logic [31:0] retire_instruction;
    logic retire_event;
    logic retire_store_event;
    logic branch_event;
    logic redirect_event;
    logic icache_hit_event;
    logic icache_miss_event;
    logic dcache_hit_event;
    logic dcache_miss_event;
    logic muldiv_issue_event;

    logic [63:0] cycle_count;
    logic [63:0] retire_count;
    logic [63:0] stall_cycle_count;
    logic [63:0] branch_count;
    logic [63:0] redirect_count;
    logic [63:0] icache_hit_count;
    logic [63:0] icache_miss_count;
    logic [63:0] dcache_hit_count;
    logic [63:0] dcache_miss_count;
    logic [63:0] store_count;
    logic [63:0] muldiv_issue_count;

    core_pipeline #(
        .IMEM_WORDS       (IMEM_WORDS),
        .DMEM_WORDS       (DMEM_WORDS),
        .CACHE_LINE_WORDS (CACHE_LINE_WORDS),
        .ICACHE_NUM_SETS  (4),
        .DCACHE_NUM_SETS  (DCACHE_NUM_SETS),
        .DCACHE_NUM_WAYS  (DCACHE_NUM_WAYS),
        .IMEM_LATENCY     (5),
        .DMEM_LATENCY     (9)
    ) dut (
        .clk_i                 (clk),
        .rst_i                 (rst),
        .current_pc_o          (pipeline_pc),
        .instruction_o         (pipeline_instruction),
        .halted_o              (pipeline_halted),
        .illegal_instruction_o (pipeline_illegal),
        .instruction_fault_o   (pipeline_ifault),
        .data_fault_o          (pipeline_dfault)
    );

    core_single_cycle #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_WORDS(DMEM_WORDS)
    ) reference_core (
        .clk_i                 (clk),
        .rst_i                 (rst),
        .current_pc_o          (reference_pc),
        .instruction_o         (reference_instruction),
        .halted_o              (reference_halted),
        .illegal_instruction_o (reference_illegal),
        .instruction_fault_o   (reference_ifault),
        .data_fault_o          (reference_dfault)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    always_comb begin
        retire_instruction = INSTRUCTION_NOP;
        if (dut.mem_wb_q.pc[31:2] < IMEM_WORDS)
            retire_instruction = instruction_image[dut.mem_wb_q.pc[31:2]];
    end

    // Halts and faults stop the current educational core instead of completing
    // a normal architectural retirement, so they are excluded from IPC.
    assign retire_event = dut.mem_wb_q.valid &&
                          !dut.mem_wb_q.halt && !dut.commit_fault;
    assign retire_store_event = retire_event &&
                                (retire_instruction[6:0] == OP_STORE);
    assign branch_event = dut.id_ex_q.valid && !dut.stall_id_ex &&
                          (dut.id_ex_q.branch_op != BR_NONE);
    assign redirect_event = dut.ex_redirect && !dut.mem_stall;
    assign icache_hit_event = dut.icache_resp_valid &&
                              dut.u_icache.cache_hit &&
                              !dut.stall_if_id && !dut.flush_if_id;
    assign icache_miss_event = dut.imem_req_valid && dut.imem_req_ready;
    assign dcache_hit_event = dut.data_response_fire && dut.dcache_resp_hit;
    assign dcache_miss_event = dut.data_response_fire && dut.dcache_resp_miss;
    assign muldiv_issue_event = dut.u_muldiv_unit.issue;

    architecture_counters counters (
        .clk                  (clk),
        .rst                  (rst),
        .active               (!pipeline_halted),
        .retire_event         (retire_event),
        .stall_event          (dut.pc_stall),
        .branch_event         (branch_event),
        .redirect_event       (redirect_event),
        .icache_hit_event     (icache_hit_event),
        .icache_miss_event    (icache_miss_event),
        .dcache_hit_event     (dcache_hit_event),
        .dcache_miss_event    (dcache_miss_event),
        .store_event          (retire_store_event),
        .muldiv_issue_event   (muldiv_issue_event),
        .cycle_count          (cycle_count),
        .retire_count         (retire_count),
        .stall_cycle_count    (stall_cycle_count),
        .branch_count         (branch_count),
        .redirect_count       (redirect_count),
        .icache_hit_count     (icache_hit_count),
        .icache_miss_count    (icache_miss_count),
        .dcache_hit_count     (dcache_hit_count),
        .dcache_miss_count    (dcache_miss_count),
        .store_count          (store_count),
        .muldiv_issue_count   (muldiv_issue_count)
    );

    function automatic logic [31:0] encode_u(
        input logic [19:0] immediate,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        return {immediate, rd, opcode};
    endfunction

    function automatic logic [31:0] encode_i(
        input logic [11:0] immediate,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        return {immediate, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] encode_r(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        return {funct7, rs2, rs1, funct3, rd, OP_REG};
    endfunction

    function automatic logic [31:0] encode_s(
        input logic [11:0] immediate,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        return {
            immediate[11:5], rs2, rs1, funct3,
            immediate[4:0], OP_STORE
        };
    endfunction

    function automatic logic [31:0] encode_b(
        input logic [12:0] immediate,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        return {
            immediate[12], immediate[10:5], rs2, rs1, funct3,
            immediate[4:1], immediate[11], OP_BRANCH
        };
    endfunction

    function automatic logic [31:0] encode_j(
        input logic [20:0] immediate,
        input logic [4:0] rd
    );
        return {
            immediate[20], immediate[10:1], immediate[11],
            immediate[19:12], rd, OP_JAL
        };
    endfunction

    task automatic write_instruction(
        input int unsigned word_index,
        input logic [31:0] value
    );
        instruction_image[word_index] = value;
        reference_core.u_imem.mem[word_index] = value;
        dut.u_imem.mem[word_index / CACHE_LINE_WORDS]
            [(word_index % CACHE_LINE_WORDS) * 32 +: 32] = value;
    endtask

    task automatic emit(input logic [31:0] value);
        write_instruction(next_word, value);
        next_word++;
    endtask

    task automatic emit_taken_branch(
        input logic [2:0] funct3,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [11:0] failure_code
    );
        emit(encode_b(13'd8, rs2, rs1, funct3));
        emit(encode_i(failure_code, 5'd0, 3'b000, 5'd31, OP_IMM));
    endtask

    task automatic check_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected %08h, got %08h", name, expected, actual);
            errors++;
        end
    endtask

    function automatic logic [31:0] read_pipeline_word(
        input int unsigned word_index
    );
        logic [31:0] address;
        logic [SET_INDEX_BITS-1:0] set_index;
        logic [TAG_BITS-1:0] tag_value;
        logic [CACHE_LINE_WORDS*32-1:0] line_value;
        logic found;

        address = word_index * 4;
        set_index = address[LINE_OFFSET_BITS +: SET_INDEX_BITS];
        tag_value = address[31 -: TAG_BITS];
        line_value = dut.u_dmem.mem[word_index / CACHE_LINE_WORDS];
        found = 1'b0;

        for (int way = 0; way < DCACHE_NUM_WAYS; way++) begin
            if (dut.u_dcache.valid_array[set_index][way] &&
                (dut.u_dcache.tag_array[set_index][way] == tag_value)) begin
                line_value = dut.u_dcache.data_array[set_index][way];
                found = 1'b1;
            end
        end

        return line_value[(word_index % CACHE_LINE_WORDS) * 32 +: 32];
    endfunction

    // Procedural protocol checks are used instead of SVA so this runs on the
    // available Questa Starter license.
    always @(posedge clk) begin
        int unsigned instruction_word;

        if (rst) begin
            store_requests = 0;
            store_responses = 0;
            retired_stores = 0;
            muldiv_issues = 0;
            retired_muldiv = 0;
            expect_mem_hold = 1'b0;
            held_pc = '0;
            held_id_ex = ID_EX_BUBBLE;
            held_ex_mem = EX_MEM_BUBBLE;

            for (int index = 0; index < IMEM_WORDS; index++) begin
                store_issue_by_word[index] = 0;
                muldiv_issue_by_word[index] = 0;
            end
        end
        else begin
            if (expect_mem_hold) begin
                if (dut.pc !== held_pc) begin
                    $error("PC changed while a D-cache miss held the pipeline");
                    errors++;
                end
                if (dut.id_ex_q !== held_id_ex) begin
                    $error("ID/EX changed while a D-cache miss held the pipeline");
                    errors++;
                end
                if (dut.ex_mem_q !== held_ex_mem) begin
                    $error("EX/MEM changed while a D-cache miss held the pipeline");
                    errors++;
                end
            end

            expect_mem_hold = dut.mem_stall;
            held_pc = dut.pc;
            held_id_ex = dut.id_ex_q;
            held_ex_mem = dut.ex_mem_q;

            if (dut.u_dcache.cpu_req_valid && dut.u_dcache.cpu_req_ready &&
                dut.u_dcache.cpu_req_write) begin
                instruction_word = dut.ex_mem_q.pc[31:2];
                store_requests++;
                store_issue_by_word[instruction_word]++;
                if (store_issue_by_word[instruction_word] != 1) begin
                    $error("Store at PC %08h issued more than once", dut.ex_mem_q.pc);
                    errors++;
                end
            end

            if (dut.data_response_fire && dut.ex_mem_q.mem_write)
                store_responses++;

            if (retire_store_event) retired_stores++;

            if (muldiv_issue_event) begin
                instruction_word = dut.id_ex_q.pc[31:2];
                muldiv_issues++;
                muldiv_issue_by_word[instruction_word]++;
                if (muldiv_issue_by_word[instruction_word] != 1) begin
                    $error("MUL/DIV at PC %08h reissued", dut.id_ex_q.pc);
                    errors++;
                end
            end

            if (retire_event &&
                (retire_instruction[6:0] == OP_REG) &&
                (retire_instruction[31:25] == 7'b0000001))
                retired_muldiv++;
        end
    end

    initial begin
        errors = 0;
        elapsed_cycles = 0;
        next_word = 0;
        rst = 1'b1;

        #1;
        for (int word_index = 0; word_index < IMEM_WORDS; word_index++)
            write_instruction(word_index, INSTRUCTION_NOP);

        // Upper-immediate and immediate ALU instructions.
        emit(encode_u(20'h12345, 5'd1, OP_LUI));
        emit(encode_u(20'h00000, 5'd2, OP_AUIPC));
        emit(encode_i(12'd5,   5'd0, 3'b000, 5'd3,  OP_IMM));
        emit(encode_i(12'hff0, 5'd0, 3'b000, 5'd4,  OP_IMM));
        emit(encode_i(12'd0,   5'd4, 3'b010, 5'd5,  OP_IMM));
        emit(encode_i(12'd1,   5'd4, 3'b011, 5'd6,  OP_IMM));
        emit(encode_i(12'd3,   5'd3, 3'b100, 5'd7,  OP_IMM));
        emit(encode_i(12'd8,   5'd3, 3'b110, 5'd8,  OP_IMM));
        emit(encode_i(12'd7,   5'd8, 3'b111, 5'd9,  OP_IMM));
        emit(encode_i(12'd3,   5'd3, 3'b001, 5'd10, OP_IMM));
        emit(encode_i(12'd2,   5'd4, 3'b101, 5'd11, OP_IMM));
        emit(encode_i(12'h402, 5'd4, 3'b101, 5'd12, OP_IMM));

        // Register-register ALU instructions.
        emit(encode_r(7'b0000000, 5'd8, 5'd3, 3'b000, 5'd13));
        emit(encode_r(7'b0100000, 5'd3, 5'd8, 3'b000, 5'd14));
        emit(encode_r(7'b0000000, 5'd3, 5'd3, 3'b001, 5'd15));
        emit(encode_r(7'b0000000, 5'd3, 5'd4, 3'b010, 5'd16));
        emit(encode_r(7'b0000000, 5'd3, 5'd4, 3'b011, 5'd17));
        emit(encode_r(7'b0000000, 5'd8, 5'd3, 3'b100, 5'd18));
        emit(encode_r(7'b0000000, 5'd3, 5'd4, 3'b101, 5'd19));
        emit(encode_r(7'b0100000, 5'd3, 5'd4, 3'b101, 5'd20));
        emit(encode_r(7'b0000000, 5'd8, 5'd3, 3'b110, 5'd21));
        emit(encode_r(7'b0000000, 5'd8, 5'd3, 3'b111, 5'd22));

        // Every RV32I store and load width/sign variant.
        emit(encode_i(12'd0, 5'd0, 3'b000, 5'd23, OP_IMM));
        emit(encode_s(12'd0, 5'd13, 5'd23, 3'b010));
        emit(encode_s(12'd4, 5'd4,  5'd23, 3'b000));
        emit(encode_s(12'd6, 5'd1,  5'd23, 3'b001));
        emit(encode_i(12'd0, 5'd23, 3'b010, 5'd24, OP_LOAD));
        emit(encode_i(12'd4, 5'd23, 3'b000, 5'd25, OP_LOAD));
        emit(encode_i(12'd4, 5'd23, 3'b100, 5'd26, OP_LOAD));
        emit(encode_i(12'd6, 5'd23, 3'b001, 5'd27, OP_LOAD));
        emit(encode_i(12'd6, 5'd23, 3'b101, 5'd28, OP_LOAD));

        // Every branch condition is taken and must flush its following write.
        emit_taken_branch(3'b000, 5'd3, 5'd3, 12'd1);
        emit_taken_branch(3'b001, 5'd8, 5'd3, 12'd2);
        emit_taken_branch(3'b100, 5'd3, 5'd4, 12'd3);
        emit_taken_branch(3'b101, 5'd3, 5'd8, 12'd4);
        emit_taken_branch(3'b110, 5'd4, 5'd3, 12'd5);
        emit_taken_branch(3'b111, 5'd3, 5'd4, 12'd6);

        // JAL and JALR each skip one wrong-path write to x31.
        emit(encode_j(21'd8, 5'd29));
        emit(encode_i(12'd7, 5'd0, 3'b000, 5'd31, OP_IMM));
        emit(encode_i(12'd193, 5'd0, 3'b000, 5'd30, OP_IMM));
        emit(encode_i(12'd0, 5'd30, 3'b000, 5'd29, OP_JALR));
        emit(encode_i(12'd8, 5'd0, 3'b000, 5'd31, OP_IMM));

        emit(32'h0000_000f); // FENCE
        emit(32'h0000_100f); // FENCE.I

        // Every RV32M operation.
        emit(encode_r(7'b0000001, 5'd3, 5'd4, 3'b000, 5'd10));
        emit(encode_r(7'b0000001, 5'd3, 5'd4, 3'b001, 5'd11));
        emit(encode_r(7'b0000001, 5'd8, 5'd4, 3'b010, 5'd12));
        emit(encode_r(7'b0000001, 5'd8, 5'd4, 3'b011, 5'd13));
        emit(encode_r(7'b0000001, 5'd3, 5'd4, 3'b100, 5'd14));
        emit(encode_r(7'b0000001, 5'd3, 5'd8, 3'b101, 5'd15));
        emit(encode_r(7'b0000001, 5'd3, 5'd4, 3'b110, 5'd16));
        emit(encode_r(7'b0000001, 5'd3, 5'd8, 3'b111, 5'd17));

        // Load-use forwarding plus a final store/load of a MUL result.
        emit(encode_i(12'd0, 5'd0, 3'b010, 5'd18, OP_LOAD));
        emit(encode_r(7'b0000000, 5'd3, 5'd18, 3'b000, 5'd19));
        emit(encode_s(12'd8, 5'd10, 5'd0, 3'b010));
        emit(encode_i(12'd8, 5'd0, 3'b010, 5'd20, OP_LOAD));
        emit(INSTRUCTION_EBREAK);

        if (next_word != 63) begin
            $fatal(1, "Internal test construction error: emitted %0d words", next_word);
        end

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        while (!(pipeline_halted && reference_halted) &&
               (elapsed_cycles < MAX_CYCLES)) begin
            @(posedge clk);
            #1;
            elapsed_cycles++;

            if (pipeline_illegal || pipeline_ifault || pipeline_dfault) begin
                $error("Pipeline fault at PC %08h: illegal=%b ifault=%b dfault=%b",
                       pipeline_pc, pipeline_illegal, pipeline_ifault, pipeline_dfault);
                errors++;
                break;
            end

            if (reference_illegal || reference_ifault || reference_dfault) begin
                $error("Reference fault at PC %08h: illegal=%b ifault=%b dfault=%b",
                       reference_pc, reference_illegal, reference_ifault, reference_dfault);
                errors++;
                break;
            end
        end

        if (!pipeline_halted || !reference_halted) begin
            $error("Cores did not both halt: pipeline=%b reference=%b cycles=%0d",
                   pipeline_halted, reference_halted, elapsed_cycles);
            errors++;
        end

        for (int reg_index = 0; reg_index < 32; reg_index++) begin
            check_value(
                dut.u_regfile.regs[reg_index],
                reference_core.u_regfile.regs[reg_index],
                $sformatf("differential x%0d", reg_index)
            );
        end

        for (int word_index = 0; word_index < 16; word_index++) begin
            check_value(
                read_pipeline_word(word_index),
                reference_core.u_dmem.mem[word_index],
                $sformatf("coherent memory word %0d", word_index)
            );
        end

        // Independent architectural sentinels prevent a shared RTL bug from
        // making both cores agree on an obviously incorrect final state.
        check_value(dut.u_regfile.regs[0],  32'h0000_0000, "x0");
        check_value(dut.u_regfile.regs[1],  32'h1234_5000, "LUI");
        check_value(dut.u_regfile.regs[2],  32'h0000_0004, "AUIPC");
        check_value(dut.u_regfile.regs[10], 32'hffff_ffb0, "MUL");
        check_value(dut.u_regfile.regs[13], 32'h0000_000c, "MULHU");
        check_value(dut.u_regfile.regs[20], 32'hffff_ffb0, "stored MUL result");
        check_value(dut.u_regfile.regs[29], 32'h0000_00bc, "JALR link");
        check_value(dut.u_regfile.regs[31], 32'h0000_0000, "flushed writes");
        check_value(read_pipeline_word(0), 32'h0000_0012, "memory word 0");
        check_value(read_pipeline_word(1), 32'h5000_00f0, "memory word 1");
        check_value(read_pipeline_word(2), 32'hffff_ffb0, "memory word 2");

        if (store_requests != EXPECTED_STORES) begin
            $error("Expected %0d store requests, observed %0d",
                   EXPECTED_STORES, store_requests);
            errors++;
        end
        if (store_responses != EXPECTED_STORES) begin
            $error("Expected %0d store responses, observed %0d",
                   EXPECTED_STORES, store_responses);
            errors++;
        end
        if (retired_stores != EXPECTED_STORES) begin
            $error("Expected %0d retired stores, observed %0d",
                   EXPECTED_STORES, retired_stores);
            errors++;
        end
        if (muldiv_issues != EXPECTED_MULDIV || retired_muldiv != EXPECTED_MULDIV) begin
            $error("MUL/DIV count mismatch: issues=%0d retired=%0d expected=%0d",
                   muldiv_issues, retired_muldiv, EXPECTED_MULDIV);
            errors++;
        end
        if (retire_count != EXPECTED_RETIRES) begin
            $error("Expected %0d retired instructions, observed %0d",
                   EXPECTED_RETIRES, retire_count);
            errors++;
        end
        if ((dcache_hit_count + dcache_miss_count) != EXPECTED_DACCESS) begin
            $error("Expected %0d D-cache responses, observed %0d",
                   EXPECTED_DACCESS, dcache_hit_count + dcache_miss_count);
            errors++;
        end
        if ((branch_count != 6) || (redirect_count != 8)) begin
            $error("Control-flow counts incorrect: branches=%0d redirects=%0d",
                   branch_count, redirect_count);
            errors++;
        end
        if ((stall_cycle_count == 0) || (icache_miss_count == 0) ||
            (dcache_miss_count == 0)) begin
            $error("Stress test did not exercise all required stall/miss paths");
            errors++;
        end

        $display("PERF: cycles=%0d retired=%0d stalls=%0d branches=%0d redirects=%0d",
                 cycle_count, retire_count, stall_cycle_count,
                 branch_count, redirect_count);
        $display("PERF: I$ accepted_hits=%0d line_misses=%0d D$ hits=%0d misses=%0d",
                 icache_hit_count, icache_miss_count,
                 dcache_hit_count, dcache_miss_count);
        $display("PERF: stores=%0d muldiv_issues=%0d",
                 store_count, muldiv_issue_count);

        if (errors == 0)
            $display("PASS: core_pipeline_scoreboard_tb (%0d cycles)", elapsed_cycles);
        else
            $fatal(1, "FAIL: core_pipeline_scoreboard_tb had %0d errors", errors);

        $finish;
    end

endmodule
