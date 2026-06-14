/*
behavior:
async reads, sync writes
sign/zero extension is done internally so writeback is already 32 bits
doesnt check alignment 

MEM_INIT can be assigned to a hex file to preload memory 

*/
import rv32i_pkg::*;

module dmem #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 1024,
    parameter string MEM_INIT = ""
) (
    input  logic             clk,
    input  logic [WIDTH-1:0] addr,
    input  logic [WIDTH-1:0] wr_data,
    input  logic [      2:0] funct3,     //width + sign 
    input  logic             mem_write,  //1 for store
    output logic [WIDTH-1:0] rd_data     //sign/zero extended for loads
);

    //memory block
    logic [WIDTH-1:0] mem[0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
        if (MEM_INIT != "") $readmemh(MEM_INIT, mem);
    end

    //addr decomp
    //word_addr indexes, byte_off selects the lane
    localparam int ADDR_WIDTH = $clog2(DEPTH);  //addr width in words
    logic [ADDR_WIDTH-1:0] word_addr;
    logic [1:0] byte_off;

    assign word_addr = addr[ADDR_WIDTH+1:2];  //drop lower 2 bits
    assign byte_off  = addr[1:0];

    //async read
    logic [WIDTH-1:0] word;
    assign word = mem[word_addr];

    always_comb begin
        case (funct3)
            // byte loads
            MEM_BYTE:
            case (byte_off)
                2'd0: rd_data = {{24{word[7]}}, word[7:0]};
                2'd1: rd_data = {{24{word[15]}}, word[15:8]};
                2'd2: rd_data = {{24{word[23]}}, word[23:16]};
                2'd3: rd_data = {{24{word[31]}}, word[31:24]};
            endcase

            MEM_BYTEU:
            case (byte_off)
                2'd0: rd_data = {24'd0, word[7:0]};
                2'd1: rd_data = {24'd0, word[15:8]};
                2'd2: rd_data = {24'd0, word[23:16]};
                2'd3: rd_data = {24'd0, word[31:24]};
            endcase

            //half word loads
            MEM_HALF:
            case (byte_ff[1])
                1'b0: rd_data = {{16{word[15]}}, word[15:0]};
                1'b1: rd_data = {{16{word[31]}}, word[31:16]};
            endcase

            MEM_HALFU:
            case (byte_off[1])
                1'b0: rd_data = {16'd0, word[15:0]};
                1'b1: rd_data = {16'd0, word[31:16]};
            endcase

            MEM_WORD: rd_data = word;

            default: rd_data = 32'hx;

        endcase
    end

    //sync write
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3[1:0])
                2'b00:
                case (byte_off)  //SB
                    2'd0: mem[word_addr][7:0] <= write_data[7:0];
                    2'd1: mem[word_addr][15:8] <= write_data[7:0];
                    2'd2: mem[word_addr][23:16] <= write_data[7:0];
                    2'd3: mem[word_addr][31:24] <= write_data[7:0];
                endcase

                2'b01:
                case (byte_off[1])  //SH
                    1'b0: mem[word_addr][15:0] <= wr_data[15:0];
                    1'b1: mem[word_addr][31:16] <= wr_data[15:0];

                endcase

                2'b10: //SW
                    mem[word_addr] <= wr_data;

                default: ;
            endcase
        end
    end


endmodule
