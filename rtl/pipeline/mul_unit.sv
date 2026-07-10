// Multiplier functional unit (RV32M: MUL, MULH, MULHSU, MULHU).
//
// SCAFFOLD - not yet implemented. See rtl/pipeline/README.md M-extension spec.
//
// Produces the 32-bit result selected by `op` (a funct3 value):
//   funct3 000 MUL     low 32 bits of rs1 * rs2        (sign-agnostic)
//   funct3 001 MULH    high 32 bits, signed   * signed
//   funct3 010 MULHSU  high 32 bits, signed   * unsigned
//   funct3 011 MULHU   high 32 bits, unsigned * unsigned
//
// Handshake (shared with div_unit so the wrapper treats both the same):
//   start : 1-cycle pulse. Latch operands/op on the cycle start is high.
//   busy  : unit is working; a multi-cycle/pipelined build holds this high.
//   done  : 1-cycle pulse when `result` is valid.
//
// A first implementation may be single-cycle combinational (done == start,
// busy == 0); a later build can pipeline the 33x33 product for timing.

module mul_unit #(
    parameter int WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst,

    input  logic             start,
    input  logic [      2:0] op,         // funct3 of the multiply variant
    input  logic [WIDTH-1:0] operand_a,  // rs1
    input  logic [WIDTH-1:0] operand_b,  // rs2

    output logic [WIDTH-1:0] result,
    output logic             done,
    output logic             busy
);

    // TODO: sign-extend each operand to WIDTH+1 bits per variant, form the
    // signed (WIDTH+1)x(WIDTH+1) product, then select low or high WIDTH bits.
    assign result = '0;
    assign done   = 1'b0;
    assign busy   = 1'b0;

endmodule
