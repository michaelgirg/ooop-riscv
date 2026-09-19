`timescale 1ns/1ps

module issue_queue_tb;
    import ooo_pkg::*;
    logic clk,rst,dispatch_valid,dispatch_ready,issue_valid,issue_ready;
    dispatch_packet_t dispatch_packet;
    result_bus_t result;
    rob_tag_t head_tag;
    recovery_event_t recovery;
    execution_request_t issue_request;
    logic flush_all,full,empty;
    int errors;

    issue_queue dut(.clk(clk),.rst(rst),.dispatch_valid_i(dispatch_valid),
        .dispatch_packet_i(dispatch_packet),.dispatch_ready_o(dispatch_ready),
        .result_i(result),.rob_head_tag_i(head_tag),.recovery_i(recovery),
        .flush_all_i(flush_all),.issue_valid_o(issue_valid),
        .issue_request_o(issue_request),.issue_ready_i(issue_ready),
        .full_o(full),.empty_o(empty));
    initial clk=0; always #5 clk=~clk;
    task automatic check(input logic c,input string n);
        if(!c) begin $error("%s",n); errors++; end
    endtask
    function automatic dispatch_packet_t packet(input int pos,input logic ready,
                                                  input phys_reg_t wait_tag);
        dispatch_packet_t p;
        p=DISPATCH_PACKET_EMPTY; p.uop.decoded.valid=1;
        p.uop.rob_tag.position=pos; p.source_1.used=1;
        p.source_1.ready=ready; p.source_1.tag=wait_tag;
        p.source_1.value=32'h100+pos; p.source_2.ready=1;
        return p;
    endfunction
    task automatic push(input dispatch_packet_t p);
        @(negedge clk); dispatch_packet=p; dispatch_valid=1;
        @(posedge clk); #1; dispatch_valid=0;
    endtask
    initial begin
        errors=0; rst=1; dispatch_valid=0; dispatch_packet=DISPATCH_PACKET_EMPTY;
        result=COMPLETION_EMPTY; head_tag='0; recovery=RECOVERY_EVENT_NONE;
        flush_all=0; issue_ready=0;
        repeat(2) @(posedge clk); @(negedge clk); rst=0; #1;
        check(empty&&dispatch_ready,"empty reset state");
        push(packet(0,0,40)); push(packet(1,1,0));
        check(issue_valid && issue_request.uop.rob_tag.position==1,
              "younger ready bypasses waiting older instruction");
        issue_ready=1; @(posedge clk); #1; issue_ready=0;
        check(!issue_valid,"older remains asleep");
        result=COMPLETION_EMPTY; result.valid=1; result.writes_phys=1;
        result.rd_phys=40; result.result=32'hcafe;
        @(posedge clk); #1; result=COMPLETION_EMPTY;
        check(issue_valid && issue_request.uop.rob_tag.position==0 &&
              issue_request.source_1_value==32'hcafe,"broadcast wakeup");
        issue_ready=1; @(posedge clk); #1; issue_ready=0;
        check(empty,"queue drains");

        push(packet(2,1,0)); push(packet(3,1,0));
        recovery=RECOVERY_EVENT_NONE; recovery.valid=1;
        recovery.branch_tag.position=2; #1;
        check(!issue_valid && !dispatch_ready,"recovery suppresses handshakes");
        @(posedge clk); #1; recovery=RECOVERY_EVENT_NONE; #1;
        check(issue_valid && issue_request.uop.rob_tag.position==2,
              "recovery preserves branch and removes younger entry");
        flush_all=1; @(posedge clk); #1; flush_all=0;
        check(empty,"flush clears queue");
        if(errors==0) $display("PASS: issue_queue_tb");
        else $fatal(1,"FAIL: issue_queue_tb had %0d errors",errors);
        $finish;
    end
endmodule
