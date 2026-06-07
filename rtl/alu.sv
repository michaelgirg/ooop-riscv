module alu #(
    parameter int WIDTH = 32
) (
    input logic[WIDTH-1:0] op_a,
    input logic[WIDTH-1:0] op_b,
    input logic[$clog(WIDTH)-1:0] alu_op,

    output logic[WIDTH-1:0] result,
    output logic zero
);



assign zero = (result == '0);

endmodule
