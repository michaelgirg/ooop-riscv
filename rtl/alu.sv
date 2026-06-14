import rv32i_pkg::*;

module alu #(
    parameter int WIDTH = 32
) (
    input logic [       WIDTH-1:0] op_a,
    input logic [       WIDTH-1:0] op_b,
    input logic [$clog(WIDTH)-1:0] alu_op,

    output logic [WIDTH-1:0] result,
    output logic             zero
);

    //variable shift amount
    logic [$clog2(WIDTH)-1:0] shift_amt;
    assign shift_amt = op_b[$clog2(WIDTH)-1:0];

    //SHOUTOUT UNIQUE CASE makes sure I use all possible combination of the given param

    always_comb begin
        unique case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_SLL:  result = a << shamt;
            ALU_SRL:  result = a >> shamt;
            ALU_SRA:  result = $signed(a) >>> shamt;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = {31'd0, $signed(a) < $signed(b)};
            ALU_SLTU: result = {31'd0, a < b};
            default:  result = 32'hx;
        endcase
    end

    assign zero = (result == '0);

endmodule
