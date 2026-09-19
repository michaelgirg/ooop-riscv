`timescale 1ns/1ps

module result_arbiter_tb;
    import ooo_pkg::*;
    logic clk,rst,execute_valid,execute_ready,memory_valid,memory_ready,result_ready;
    completion_t execute_result,memory_result;
    result_bus_t result;
    int errors;

    result_arbiter dut(.clk(clk),.rst(rst),.execute_valid_i(execute_valid),
        .execute_result_i(execute_result),.execute_ready_o(execute_ready),
        .memory_valid_i(memory_valid),.memory_result_i(memory_result),
        .memory_ready_o(memory_ready),.result_o(result),
        .result_ready_i(result_ready));
    initial clk=0; always #5 clk=~clk;
    task automatic check(input logic c,input string n);
        if(!c) begin $error("%s",n); errors++; end
    endtask
    initial begin
        errors=0; rst=1; execute_valid=0; memory_valid=0; result_ready=0;
        execute_result=COMPLETION_EMPTY; memory_result=COMPLETION_EMPTY;
        execute_result.rob_tag.position=1; execute_result.result=32'h1111;
        memory_result.rob_tag.position=2; memory_result.result=32'h2222;
        repeat(2) @(posedge clk); @(negedge clk); rst=0;
        execute_valid=1; memory_valid=1; #1;
        check(result.valid && result.result==32'h1111,
              "execute wins first collision");
        check(!execute_ready && !memory_ready,"backpressure routes no ready");
        result_ready=1; @(posedge clk); #1;
        check(result.result==32'h2222,"memory wins next collision fairly");
        check(memory_ready && !execute_ready,"ready routes to selected producer");
        memory_valid=0; @(posedge clk); #1;
        check(result.result==32'h1111 && execute_ready,"single execute producer");
        if(errors==0) $display("PASS: result_arbiter_tb");
        else $fatal(1,"FAIL: result_arbiter_tb had %0d errors",errors);
        $finish;
    end
endmodule
