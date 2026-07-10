import rv32i_pkg::*;

// M-extension execute wrapper.
//
// SCAFFOLD - not yet implemented. See rtl/pipeline/README.md M-extension spec.
//
// Sits in the EX stage next to the ALU. When a MUL/DIV-class instruction is in
// EX, this unit runs the operation over one or more cycles and raises `busy`,
// which the core turns into a pipeline stall (freeze PC / IF-ID / ID-EX, bubble
// EX/MEM) until `done`. On `done`, `result` is muxed into the EX result that
// feeds ex_mem.alu_result, so the value writes back through the normal WB_ALU
// path - no new writeback source is needed.
//
// funct3 selects the operation; funct3[2] splits the two sub-units:
//   funct3[2] == 0 -> mul_unit  (MUL, MULH, MULHSU, MULHU)
//   funct3[2] == 1 -> div_unit  (DIV, DIVU, REM, REMU)
//
// Single-issue: this unit handles one op at a time. It generates a one-cycle
// `start` when a new muldiv op arrives (in_valid && !busy) and ignores the EX
// inputs until it reports `done`, so a stalled op held in EX is not restarted.

module muldiv_unit (
    input  logic        clk,
    input  logic        rst,

    input  logic        in_valid,   // a real muldiv instruction is in EX
    input  logic [ 2:0] funct3,     // selects one of the 8 RV32M ops
    input  logic [31:0] rs1_data,   // already-forwarded EX operand a
    input  logic [31:0] rs2_data,   // already-forwarded EX operand b

    output logic [31:0] result,
    output logic        busy,       // -> pipeline stall while high
    output logic        done        // 1-cycle pulse: result valid this cycle
);

    // TODO: instantiate mul_unit and div_unit, route `start` to the selected
    // sub-unit, mux `result`/`done`, and hold `busy` across the operation.
    assign result = '0;
    assign busy   = 1'b0;
    assign done   = 1'b0;

endmodule
