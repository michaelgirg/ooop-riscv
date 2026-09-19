`timescale 1ns/1ps

module memory_queue_tb;
    import rv32i_pkg::*;
    import ooo_pkg::*;
    logic clk,rst,dispatch_valid,dispatch_ready,result_ready;
    dispatch_packet_t dispatch_packet;
    result_bus_t broadcast;
    rob_tag_t head_tag;
    recovery_event_t recovery;
    logic flush_all,result_valid;
    completion_t result;
    logic store_commit_valid,store_done,store_fault;
    rob_tag_t store_commit_tag;
    logic req_valid,req_write,req_ready,resp_ready,resp_valid,resp_hit,resp_miss,resp_fault;
    logic [31:0] req_addr,req_wdata,resp_rdata;
    logic [2:0] req_funct3;
    logic full,empty;
    int errors,request_count;

    memory_queue dut(.clk(clk),.rst(rst),.dispatch_valid_i(dispatch_valid),
        .dispatch_packet_i(dispatch_packet),.dispatch_ready_o(dispatch_ready),
        .result_i(broadcast),.rob_head_tag_i(head_tag),.recovery_i(recovery),
        .flush_all_i(flush_all),.result_valid_o(result_valid),.result_o(result),
        .result_ready_i(result_ready),.store_commit_valid_i(store_commit_valid),
        .store_commit_tag_i(store_commit_tag),.store_commit_done_o(store_done),
        .store_commit_fault_o(store_fault),.dcache_req_valid_o(req_valid),
        .dcache_req_write_o(req_write),.dcache_req_addr_o(req_addr),
        .dcache_req_wdata_o(req_wdata),.dcache_req_funct3_o(req_funct3),
        .dcache_req_ready_i(req_ready),.dcache_resp_ready_o(resp_ready),
        .dcache_resp_valid_i(resp_valid),.dcache_resp_rdata_i(resp_rdata),
        .dcache_resp_hit_i(resp_hit),.dcache_resp_miss_i(resp_miss),
        .dcache_resp_fault_i(resp_fault),.full_o(full),.empty_o(empty));
    initial clk=0; always #5 clk=~clk;
    always @(posedge clk) if(req_valid&&req_ready) request_count++;
    task automatic check(input logic c,input string n);
        if(!c) begin $error("%s",n); errors++; end
    endtask
    function automatic dispatch_packet_t mem_packet(input int pos,input logic store_op,
                                                      input logic [31:0] base,
                                                      input logic [31:0] data);
        dispatch_packet_t p;
        p=DISPATCH_PACKET_EMPTY; p.uop.decoded.valid=1;
        p.uop.rob_tag.position=pos;
        p.uop.decoded.uop_class=store_op?UOP_STORE:UOP_LOAD;
        p.uop.decoded.mem_size=MEM_WORD; p.uop.decoded.immediate=4;
        p.uop.has_phys_destination=!store_op; p.uop.rd_phys=40;
        p.source_1.used=1; p.source_1.ready=1; p.source_1.value=base;
        p.source_2.used=store_op; p.source_2.ready=1; p.source_2.value=data;
        return p;
    endfunction
    task automatic push(input dispatch_packet_t p);
        @(negedge clk); dispatch_packet=p; dispatch_valid=1;
        @(posedge clk); #1; dispatch_valid=0;
    endtask
    initial begin
        rob_tag_t store_tag,load_tag;
        errors=0; request_count=0; rst=1; dispatch_valid=0;
        dispatch_packet=DISPATCH_PACKET_EMPTY; broadcast=COMPLETION_EMPTY;
        head_tag='0; recovery=RECOVERY_EVENT_NONE; flush_all=0;
        result_ready=0; store_commit_valid=0; store_commit_tag='0;
        req_ready=1; resp_valid=0; resp_rdata=0; resp_hit=1; resp_miss=0; resp_fault=0;
        repeat(2) @(posedge clk); @(negedge clk); rst=0;

        store_tag='0; store_tag.position=0;
        push(mem_packet(0,1,32'h100,32'hdead_beef));
        repeat(3) begin @(posedge clk); #1; if(result_valid) break; end
        check(result_valid&&result.memory_address==32'h104&&
              result.store_data==32'hdead_beef,"store address completion");
        check(request_count==0&&!req_valid,"store blocked before commit");
        result_ready=1; @(posedge clk); #1; result_ready=0;
        repeat(2) begin @(posedge clk); #1; end
        check(request_count==0,"store remains blocked without authorization");

        store_commit_tag=store_tag; store_commit_valid=1; #1;
        check(req_valid&&req_write&&req_addr==32'h104,
              "authorized store request");
        @(posedge clk); #1;
        check(request_count==1&&!req_valid,"store request issued exactly once");
        resp_valid=1; #1;
        check(resp_ready&&store_done&&!store_fault,"store response commits");
        @(posedge clk); #1; resp_valid=0; store_commit_valid=0;

        load_tag='0; load_tag.position=1;
        head_tag.position=0;
        push(mem_packet(1,0,32'h200,0));
        repeat(2) begin @(posedge clk); #1; end
        check(request_count==1,"load waits until ROB head");
        head_tag=load_tag; #1;
        check(req_valid&&!req_write&&req_addr==32'h204,"head load request");
        @(posedge clk); #1;
        resp_rdata=32'h1234_5678; resp_valid=1; #1;
        check(resp_ready,"load response accepted");
        @(posedge clk); #1; resp_valid=0;
        check(result_valid&&result.writes_phys&&result.rd_phys==40&&
              result.result==32'h1234_5678,"load completion payload");
        result_ready=1; @(posedge clk); #1;

        // Misalignment completes as a precise exception without a request.
        result_ready=0; head_tag.position=2;
        push(mem_packet(2,0,32'h201,0)); // address 0x205
        repeat(3) begin @(posedge clk); #1; if(result_valid) break; end
        check(result_valid&&result.exception_valid&&
              result.exception_cause==EXC_LOAD_ADDRESS_MISALIGNED,
              "misaligned load exception");
        check(request_count==2,"misaligned load does not access cache");

        if(errors==0) $display("PASS: memory_queue_tb");
        else $fatal(1,"FAIL: memory_queue_tb had %0d errors",errors);
        $finish;
    end
endmodule
