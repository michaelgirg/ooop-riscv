/*
32 reg wide read-first regfile, sync write async read with reg0 hardcoded to 0 

*/

module regfile #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 32
) (
    input logic clk,

    input logic [$clog2(WIDTH)-1:0] rs1_addr,
    input logic [$clog2(WIDTH)-1:0] rs2_addr,

    output logic [WIDTH-1:0] rs1_data,
    output logic [WIDTH-1:0] rs2_data,


    input logic [$clog2(WIDTH)-1:0] rd_addr,
    input logic [        WIDTH-1:0] rd_data,
    input logic                     we
);

    logic [WIDTH-1:0] regs[DEPTH];

    //resetting all to 0 for sim

    initial begin
        for (int i = 0; i < 32; i++) regs[i] = 32'd0;
    end


    always_ff @(posedge clk) begin
        if(we && (rd_addr !=5'd0)) regs[rd_addr] <= rd_data;
    end

    assign rs1_data = rs1_addr == 5'd0 ? '0 : regs[rs1_addr];
    assign rs2_data = rs2_addr == 5'd0 ? '0 : regs[rs2_addr];;


endmodule
