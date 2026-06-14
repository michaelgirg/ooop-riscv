// Byte-addressed RV32I data memory with asynchronous reads and synchronous
// writes. Misaligned accesses are unsupported by the initial core.

module dmem #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 1024,
    parameter string MEM_INIT = ""
) (
    input  logic             clk,
    input  logic [WIDTH-1:0] addr,
    input  logic [WIDTH-1:0] wr_data,
    input  logic [      2:0] funct3,
    input  logic             mem_write,
    output logic [WIDTH-1:0] rd_data
);
    import rv32i_pkg::*;

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [WIDTH-1:0] mem[0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] word_addr;
    logic [1:0] byte_off;
    logic [WIDTH-1:0] word;
    logic address_valid;

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = '0;
        end

        if (MEM_INIT != "") begin
            $readmemh(MEM_INIT, mem);
        end
    end

    assign word_addr = addr[ADDR_WIDTH+1:2];
    assign byte_off = addr[1:0];
    assign address_valid = (addr[WIDTH-1:2] < DEPTH);
    assign word = address_valid ? mem[word_addr] : '0;

    always_comb begin
        rd_data = '0;

        case (funct3)
            LOAD_BYTE: begin
                case (byte_off)
                    2'd0: rd_data = {{24{word[7]}}, word[7:0]};
                    2'd1: rd_data = {{24{word[15]}}, word[15:8]};
                    2'd2: rd_data = {{24{word[23]}}, word[23:16]};
                    2'd3: rd_data = {{24{word[31]}}, word[31:24]};
                endcase
            end

            LOAD_BYTE_U: begin
                case (byte_off)
                    2'd0: rd_data = {24'd0, word[7:0]};
                    2'd1: rd_data = {24'd0, word[15:8]};
                    2'd2: rd_data = {24'd0, word[23:16]};
                    2'd3: rd_data = {24'd0, word[31:24]};
                endcase
            end

            LOAD_HALF: begin
                case (byte_off[1])
                    1'b0: rd_data = {{16{word[15]}}, word[15:0]};
                    1'b1: rd_data = {{16{word[31]}}, word[31:16]};
                endcase
            end

            LOAD_HALF_U: begin
                case (byte_off[1])
                    1'b0: rd_data = {16'd0, word[15:0]};
                    1'b1: rd_data = {16'd0, word[31:16]};
                endcase
            end

            LOAD_WORD: rd_data = word;
            default:   rd_data = '0;
        endcase
    end


    /*
    We use an always block since an always_ff block enforces a single writer rule so 
    any var assigned inside cannot be assigned by another procedural block. In this case even though
    inital block runs only once at the sim startup it still counts as another write to the mem array so Questa rejected it
    */
    always @(posedge clk) begin
        if (mem_write && address_valid) begin
            case (funct3)
                STORE_BYTE: begin
                    case (byte_off)
                        2'd0: mem[word_addr][7:0] <= wr_data[7:0];
                        2'd1: mem[word_addr][15:8] <= wr_data[7:0];
                        2'd2: mem[word_addr][23:16] <= wr_data[7:0];
                        2'd3: mem[word_addr][31:24] <= wr_data[7:0];
                    endcase
                end

                STORE_HALF: begin
                    case (byte_off[1])
                        1'b0: mem[word_addr][15:0] <= wr_data[15:0];
                        1'b1: mem[word_addr][31:16] <= wr_data[15:0];
                    endcase
                end

                STORE_WORD: mem[word_addr] <= wr_data;
                default: begin
                end
            endcase
        end
    end

endmodule
