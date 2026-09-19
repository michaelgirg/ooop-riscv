`timescale 1ns/1ps

module ooo_control_tb;
    import ooo_pkg::*;
    logic clk,rst,branch_ready,trap_valid,halt,flush_all,redirect_valid;
    branch_resolution_t branch;
    logic [31:0] trap_pc,trap_value,trap_target,redirect_pc,observed_pc,observed_value;
    exception_cause_t trap_cause,observed_cause;
    recovery_event_t recovery;
    logic trap_taken,halted;
    int errors;
    ooo_control dut(.clk(clk),.rst(rst),.branch_i(branch),
        .branch_ready_o(branch_ready),.trap_valid_i(trap_valid),
        .trap_pc_i(trap_pc),.trap_cause_i(trap_cause),
        .trap_value_i(trap_value),.trap_target_i(trap_target),.halt_i(halt),
        .recovery_o(recovery),.flush_all_o(flush_all),
        .redirect_valid_o(redirect_valid),.redirect_pc_o(redirect_pc),
        .trap_taken_o(trap_taken),.trap_pc_o(observed_pc),
        .trap_cause_o(observed_cause),.trap_value_o(observed_value),
        .halted_o(halted));
    initial clk=0; always #5 clk=~clk;
    task automatic check(input logic c,input string n);
        if(!c) begin $error("%s",n); errors++; end
    endtask
    initial begin
        errors=0; rst=1; branch=BRANCH_RESOLUTION_NONE; trap_valid=0;
        trap_pc=32'h10; trap_cause=EXC_ILLEGAL_INSTRUCTION;
        trap_value=32'hbad; trap_target=32'h100; halt=0;
        repeat(2) @(posedge clk); @(negedge clk); rst=0;
        branch.valid=1; branch.mispredicted=1; branch.branch_tag.position=4;
        branch.target=32'h80; #1;
        check(branch_ready&&recovery.valid&&redirect_pc==32'h80,
              "branch recovery redirect");
        trap_valid=1; #1;
        check(trap_taken&&flush_all&&redirect_pc==32'h100&&!recovery.valid,
              "trap priority over branch");
        trap_valid=0; branch=BRANCH_RESOLUTION_NONE; halt=1; #1;
        check(flush_all&&redirect_valid,"halt flush");
        @(posedge clk); #1; halt=0;
        check(halted&&!branch_ready,"sticky halted state");
        if(errors==0) $display("PASS: ooo_control_tb");
        else $fatal(1,"FAIL: ooo_control_tb had %0d errors",errors);
        $finish;
    end
endmodule
