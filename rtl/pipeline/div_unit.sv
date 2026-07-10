// Divider functional unit (RV32M: DIV, DIVU, REM, REMU).
//
// SCAFFOLD - not yet implemented. See rtl/pipeline/README.md M-extension spec.
//
// Produces the 32-bit result selected by `op` (a funct3 value):
//   funct3 100 DIV   signed   quotient
//   funct3 101 DIVU  unsigned quotient
//   funct3 110 REM   signed   remainder
//   funct3 111 REMU  unsigned remainder
//
// RISC-V mandates results for the corner cases (NO trap is taken):
//   divide by zero: DIV/DIVU -> -1 / 0xFFFF_FFFF, REM/REMU -> dividend
//   signed overflow (-2^31 / -1): quotient -> -2^31, remainder -> 0
//
// Handshake matches mul_unit:
//   start : 1-cycle pulse; latch operands/op.
//   busy  : high while the iterative loop runs.
//   done  : 1-cycle pulse when `result` is valid.
//
// Expected implementation: an iterative shift/subtract divider (restoring or
// non-restoring), ~WIDTH+ cycles, driven by an IDLE -> ITER -> DONE FSM.

module div_unit #(
    parameter int WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst,

    input  logic             start,
    input  logic [      2:0] op,        // funct3 of the divide variant
    input  logic [WIDTH-1:0] dividend,  // rs1
    input  logic [WIDTH-1:0] divisor,   // rs2

    output logic [WIDTH-1:0] result,
    output logic             done,
    output logic             busy
);

    // TODO: take absolute values for signed ops, run the unsigned shift/subtract
    // loop, then fix up quotient/remainder signs. Handle the div-by-zero and
    // overflow corner cases before entering the loop.
    assign result = '0;
    assign done   = 1'b0;
    assign busy   = 1'b0;

endmodule
