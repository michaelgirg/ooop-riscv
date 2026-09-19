`timescale 1ns/1ps

module core_ooo_tb;
    import rv32i_pkg::*;
    import ooo_pkg::*;
    localparam int MAX_CYCLES=1000;
    logic clk,rst;
    logic ic_req_valid,ic_resp_valid,ic_resp_fault,ic_stall;
    logic [31:0] ic_req_addr,ic_resp_data;
    logic dc_req_valid,dc_req_write,dc_req_ready,dc_resp_ready;
    logic [31:0] dc_req_addr,dc_req_wdata;
    logic [2:0] dc_req_funct3;
    logic dc_resp_valid,dc_resp_hit,dc_resp_miss,dc_resp_fault;
    logic [31:0] dc_resp_rdata;
    logic [31:0] current_pc;
    logic halted,illegal_fault,instruction_fault,data_fault;
    retire_event_t retire;
    logic [31:0] imem[0:63];
    logic [31:0] dmem[0:63];
    logic i_pending;
    logic [31:0] i_pending_addr;
    logic d_pending,d_pending_write;
    logic [31:0] d_pending_addr,d_pending_data;
    logic [2:0] d_pending_funct3;
    logic [31:0] architectural[0:31];
    int errors,cycles,retired,store_requests;

    core_ooo dut(.clk(clk),.rst(rst),.icache_req_valid_o(ic_req_valid),
        .icache_req_addr_o(ic_req_addr),.icache_resp_valid_i(ic_resp_valid),
        .icache_resp_data_i(ic_resp_data),.icache_resp_fault_i(ic_resp_fault),
        .icache_stall_i(ic_stall),.dcache_req_valid_o(dc_req_valid),
        .dcache_req_write_o(dc_req_write),.dcache_req_addr_o(dc_req_addr),
        .dcache_req_wdata_o(dc_req_wdata),.dcache_req_funct3_o(dc_req_funct3),
        .dcache_req_ready_i(dc_req_ready),.dcache_resp_ready_o(dc_resp_ready),
        .dcache_resp_valid_i(dc_resp_valid),.dcache_resp_rdata_i(dc_resp_rdata),
        .dcache_resp_hit_i(dc_resp_hit),.dcache_resp_miss_i(dc_resp_miss),
        .dcache_resp_fault_i(dc_resp_fault),.trap_target_i(32'h100),
        .current_pc_o(current_pc),.halted_o(halted),
        .illegal_instruction_o(illegal_fault),
        .instruction_fault_o(instruction_fault),.data_fault_o(data_fault),
        .retire_o(retire));

    initial clk=0; always #5 clk=~clk;

    always_comb begin
        ic_resp_valid=i_pending;
        ic_resp_data=INSTRUCTION_NOP;
        ic_resp_fault=1'b0;
        ic_stall=1'b0;
        if(i_pending) begin
            if(i_pending_addr[31:8]!=0 || i_pending_addr[1:0]!=0)
                ic_resp_fault=1'b1;
            else
                ic_resp_data=imem[i_pending_addr[7:2]];
        end
        dc_req_ready=!d_pending;
        dc_resp_valid=d_pending;
        dc_resp_rdata=dmem[d_pending_addr[7:2]];
        dc_resp_hit=d_pending;
        dc_resp_miss=1'b0;
        dc_resp_fault=1'b0;
    end

    // This is testbench state rather than synthesizable design state. A normal
    // clocked block lets the initial block seed the model without violating
    // always_ff's single-driver restriction in Questa.
    always @(posedge clk) begin
        if(rst) begin
            i_pending<=0; i_pending_addr<=0;
            d_pending<=0; d_pending_write<=0; d_pending_addr<=0;
            d_pending_data<=0; d_pending_funct3<=0;
        end else begin
            if(i_pending)
                i_pending<=0;
            else if(ic_req_valid) begin
                i_pending<=1;
                i_pending_addr<=ic_req_addr;
            end

            if(d_pending&&dc_resp_ready) begin
                if(d_pending_write) begin
                    case(d_pending_funct3[1:0])
                        MEM_BYTE: dmem[d_pending_addr[7:2]][8*d_pending_addr[1:0]+:8]
                                  <= d_pending_data[7:0];
                        MEM_HALF: dmem[d_pending_addr[7:2]][16*d_pending_addr[1]+:16]
                                  <= d_pending_data[15:0];
                        default: dmem[d_pending_addr[7:2]]<=d_pending_data;
                    endcase
                end
                d_pending<=0;
            end
            if(dc_req_valid&&dc_req_ready) begin
                d_pending<=1; d_pending_write<=dc_req_write;
                d_pending_addr<=dc_req_addr; d_pending_data<=dc_req_wdata;
                d_pending_funct3<=dc_req_funct3;
                if(dc_req_write) store_requests++;
            end
        end

        if(!rst&&retire.valid) begin
            retired++;
            if(retire.writes_rd&&retire.rd_arch!=0)
                architectural[retire.rd_arch]<=retire.rd_value;
        end
    end

    task automatic check_word(input logic[31:0] actual,input logic[31:0] expected,
                              input string name);
        if(actual!==expected) begin
            $error("%s expected %08h got %08h",name,expected,actual); errors++;
        end
    endtask

    initial begin
        errors=0; cycles=0; retired=0; store_requests=0; rst=1;
        for(int i=0;i<64;i++) begin imem[i]=INSTRUCTION_NOP; dmem[i]=0; end
        for(int i=0;i<32;i++) architectural[i]=0;
        imem[0]=32'h00500093; // addi x1,x0,5
        imem[1]=32'h00700113; // addi x2,x0,7
        imem[2]=32'h002081b3; // add x3,x1,x2
        imem[3]=32'h02218233; // mul x4,x3,x2
        imem[4]=32'h00402023; // sw x4,0(x0)
        imem[5]=32'h00002283; // lw x5,0(x0)
        imem[6]=32'h00428463; // beq x5,x4,+8
        imem[7]=32'h06300313; // wrong path: addi x6,x0,99
        imem[8]=32'h00b00393; // addi x7,x0,11
        imem[9]=32'h00100073; // ebreak
        repeat(4) @(posedge clk); @(negedge clk); rst=0;
        while(!halted&&cycles<MAX_CYCLES) begin
            @(posedge clk); #1; cycles++;
            if(illegal_fault||instruction_fault||data_fault) begin
                $error("unexpected fault at cycle %0d pc=%08h",cycles,current_pc);
                errors++; break;
            end
        end
        if(!halted) begin $error("core did not halt"); errors++; end
        check_word(architectural[1],5,"x1");
        check_word(architectural[2],7,"x2");
        check_word(architectural[3],12,"x3 dependency");
        check_word(architectural[4],84,"x4 MUL");
        check_word(architectural[5],84,"x5 load");
        check_word(architectural[6],0,"x6 wrong-path squash");
        check_word(architectural[7],11,"x7 branch target");
        check_word(dmem[0],84,"committed store");
        if(store_requests!=1) begin
            $error("expected exactly one store request, got %0d",store_requests);
            errors++;
        end
        if(errors==0)
            $display("PASS: core_ooo_tb cycles=%0d retired=%0d",cycles,retired);
        else $fatal(1,"FAIL: core_ooo_tb had %0d errors",errors);
        $finish;
    end
endmodule
