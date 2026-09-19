`timescale 1ns/1ps

module ooo_frontend_tb;
    import rv32i_pkg::*;
    import ooo_pkg::*;

    logic clk, rst, redirect_valid, decoded_ready;
    logic [31:0] redirect_pc;
    logic decoded_valid;
    decoded_uop_t decoded;
    logic req_valid;
    logic [31:0] req_addr;
    logic resp_valid;
    logic [31:0] resp_data;
    logic resp_fault, cache_stall;
    logic [31:0] fetch_pc;
    int errors;

    ooo_frontend dut (.*,
        .redirect_valid_i(redirect_valid), .redirect_pc_i(redirect_pc),
        .decoded_valid_o(decoded_valid), .decoded_uop_o(decoded),
        .decoded_ready_i(decoded_ready), .icache_req_valid_o(req_valid),
        .icache_req_addr_o(req_addr), .icache_resp_valid_i(resp_valid),
        .icache_resp_data_i(resp_data), .icache_resp_fault_i(resp_fault),
        .icache_stall_i(cache_stall), .fetch_pc_o(fetch_pc));

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic check(input logic condition, input string name);
        if (!condition) begin $error("%s", name); errors++; end
    endtask

    task automatic send_response(input logic [31:0] instruction,
                                 input logic fault);
        @(negedge clk);
        resp_data = instruction;
        resp_fault = fault;
        resp_valid = 1'b1;
        @(posedge clk); #1;
        resp_valid = 1'b0;
        resp_fault = 1'b0;
    endtask

    initial begin
        errors = 0;
        rst = 1; redirect_valid = 0; redirect_pc = 0; decoded_ready = 0;
        resp_valid = 0; resp_data = 0; resp_fault = 0; cache_stall = 0;
        repeat (3) @(posedge clk); @(negedge clk); rst = 0; #1;
        check(req_valid && req_addr == 0, "reset fetch request");

        send_response(32'h0050_0093, 1'b0); // addi x1,x0,5
        check(decoded_valid, "decoded instruction valid");
        check(decoded.uop_class == UOP_ALU && decoded.writes_rd,
              "ADDI decode class/destination");
        check(decoded.rd_arch == 1 && decoded.immediate == 5,
              "ADDI fields");
        check(!req_valid, "buffer backpressure stops fetch");

        decoded_ready = 1'b1;
        #1;
        check(req_valid && req_addr == 4, "consume and fetch next PC");
        @(negedge clk); decoded_ready = 1'b0;

        // Redirect must discard a response from the old path.
        resp_valid = 1'b1; resp_data = 32'h0630_0313;
        redirect_valid = 1'b1; redirect_pc = 32'h40;
        @(posedge clk); #1;
        resp_valid = 0; redirect_valid = 0;
        check(!decoded_valid && fetch_pc == 32'h40,
              "redirect discards wrong-path response");

        send_response(32'hffff_ffff, 1'b0);
        check(decoded.exception_valid &&
              decoded.exception_cause == EXC_ILLEGAL_INSTRUCTION,
              "illegal instruction exception");
        decoded_ready = 1; @(posedge clk); #1; decoded_ready = 0;

        send_response(INSTRUCTION_NOP, 1'b1);
        check(decoded.exception_valid &&
              decoded.exception_cause == EXC_INSTRUCTION_ACCESS_FAULT,
              "instruction access fault");

        if (errors == 0) $display("PASS: ooo_frontend_tb");
        else $fatal(1, "FAIL: ooo_frontend_tb had %0d errors", errors);
        $finish;
    end
endmodule
