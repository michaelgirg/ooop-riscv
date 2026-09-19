`timescale 1ns/1ps

module execute_cluster_tb;
    import rv32i_pkg::*;
    import ooo_pkg::*;
    logic clk,rst,issue_valid,issue_ready,result_valid,result_ready;
    execution_request_t request;
    rob_tag_t head_tag;
    recovery_event_t recovery;
    completion_t result;
    logic branch_valid,branch_ready,flush_all;
    branch_resolution_t branch;
    int errors;

    execute_cluster dut(.clk(clk),.rst(rst),.issue_valid_i(issue_valid),
        .issue_request_i(request),.issue_ready_o(issue_ready),
        .rob_head_tag_i(head_tag),.recovery_i(recovery),.flush_all_i(flush_all),
        .result_valid_o(result_valid),.result_o(result),
        .result_ready_i(result_ready),.branch_valid_o(branch_valid),
        .branch_o(branch),.branch_ready_i(branch_ready));
    initial clk=0; always #5 clk=~clk;
    task automatic check(input logic c,input string n);
        if(!c) begin $error("%s",n); errors++; end
    endtask
    function automatic execution_request_t base_req(input int pos);
        execution_request_t r;
        r=EXECUTION_REQUEST_EMPTY; r.uop.decoded.valid=1;
        r.uop.rob_tag.position=pos; r.uop.has_phys_destination=1;
        r.uop.rd_phys=phys_reg_t'(32+pos); r.source_1_value=7;
        r.source_2_value=5; r.uop.decoded.alu_op=ALU_ADD;
        r.uop.decoded.uop_class=UOP_ALU;
        r.uop.decoded.operand_a_sel=OPERAND_A_RS1;
        r.uop.decoded.operand_b_sel=OPERAND_B_RS2;
        return r;
    endfunction
    task automatic send(input execution_request_t r);
        @(negedge clk); request=r; issue_valid=1;
        while(!issue_ready) @(negedge clk);
        @(posedge clk); #1; issue_valid=0;
    endtask
    initial begin
        execution_request_t r;
        errors=0; rst=1; issue_valid=0; request=EXECUTION_REQUEST_EMPTY;
        head_tag='0; recovery=RECOVERY_EVENT_NONE; flush_all=0;
        result_ready=0; branch_ready=0;
        repeat(2) @(posedge clk); @(negedge clk); rst=0;
        send(base_req(0));
        check(result_valid && result.result==12 && result.rd_phys==32,
              "ALU completion");
        repeat(2) begin @(posedge clk); #1;
            check(result_valid&&result.result==12,"result held under backpressure");
        end
        result_ready=1; @(posedge clk); #1; result_ready=0;

        r=base_req(1); r.uop.has_phys_destination=0;
        r.uop.decoded.uop_class=UOP_BRANCH;
        r.uop.decoded.control_flow=CONTROL_FLOW_BRANCH;
        r.uop.decoded.branch_op=BR_EQ; r.source_2_value=7;
        r.uop.decoded.pc=32'h20; r.uop.decoded.immediate=8;
        r.uop.decoded.prediction.valid=1; r.uop.decoded.prediction.taken=0;
        r.uop.decoded.prediction.target=32'h24;
        send(r);
        check(branch_valid&&branch.mispredicted&&branch.target==32'h28,
              "taken branch resolution");
        check(result_valid&&result.branch_valid,"branch ROB completion");
        result_ready=1; branch_ready=1; @(posedge clk); #1;
        result_ready=0; branch_ready=0;

        r=base_req(2); r.uop.decoded.uop_class=UOP_MULDIV;
        r.uop.decoded.muldiv_op=MULDIV_MUL; r.source_1_value=9;
        r.source_2_value=6; send(r);
        for(int cycles=0; cycles<20 && !result_valid; cycles++) begin
            @(posedge clk); #1;
        end
        check(result_valid&&result.result==54,"MUL completion");
        result_ready=1; @(posedge clk); #1;
        result_ready=0;

        // The iterative divider must keep its originating ROB/physical tags
        // until completion, even though issue_request_i changes afterward.
        r=base_req(3); r.uop.decoded.uop_class=UOP_MULDIV;
        r.uop.decoded.muldiv_op=MULDIV_DIV; r.source_1_value=100;
        r.source_2_value=7; send(r);
        for(int cycles=0; cycles<80 && !result_valid; cycles++) begin
            @(posedge clk); #1;
        end
        check(result_valid&&result.result==14&&
              result.rob_tag.position==3,"DIV completion and tag retention");
        result_ready=1; @(posedge clk); #1;
        result_ready=0;

        // A recovering branch removes a younger long-latency operation. Its
        // eventual done pulse must be consumed without reaching writeback.
        r=base_req(5); r.uop.decoded.uop_class=UOP_MULDIV;
        r.uop.decoded.muldiv_op=MULDIV_MUL; r.source_1_value=11;
        r.source_2_value=13; send(r);
        @(negedge clk); recovery=RECOVERY_EVENT_NONE; recovery.valid=1;
        recovery.branch_tag.position=4;
        @(posedge clk); #1; recovery=RECOVERY_EVENT_NONE; #1;
        repeat(12) begin
            @(posedge clk); #1;
            check(!result_valid,"squashed MUL produces no completion");
        end

        send(base_req(6));
        check(result_valid&&result.result==12,
              "execution resumes after squashed MUL drains");
        result_ready=1; @(posedge clk); #1;

        if(errors==0) $display("PASS: execute_cluster_tb");
        else $fatal(1,"FAIL: execute_cluster_tb had %0d errors",errors);
        $finish;
    end
endmodule
