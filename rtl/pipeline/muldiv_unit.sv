import rv32i_pkg::*;

// M-extension execute wrapper.
//
// Sits in the EX stage next to the ALU. When a MUL/DIV-class instruction is in
// EX, this unit runs the operation over one or more cycles and raises `busy`,
// which the core turns into a pipeline stall (freeze PC / IF-ID, hold ID-EX,
// bubble EX/MEM) until `done`. On `done`, `result` is muxed into the EX result
// that feeds ex_mem.alu_result, so the value writes back through the normal
// WB_ALU path - no new writeback source is needed.
//
// funct3 selects the operation; funct3[2] splits the two sub-units:
//   funct3[2] == 0 -> mul_unit  (MUL, MULH, MULHSU, MULHU)
//   funct3[2] == 1 -> div_unit  (DIV, DIVU, REM, REMU)
//
// Single-issue: this unit handles one op at a time. `in_valid` stays high for
// the whole time the op is held (stalled) in EX, so a private `running` flag,
// not `in_valid`, gates `start`. Exactly one `start` pulse is issued when the
// op is first seen; the flag clears when the selected sub-unit reports done.

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

    // running = an operation has been started and has not yet reported done.
    logic running;
    logic sel_div_q;   // which sub-unit the in-flight op was routed to

    // Issue a single start pulse the cycle a new op is first seen in EX.
    logic issue;
    assign issue = in_valid && !running;

    // Sub-unit request strobes (one-cycle pulses).
    logic mul_start;
    logic div_start;
    assign mul_start = issue && !funct3[2];
    assign div_start = issue &&  funct3[2];

    // Sub-unit outputs.
    logic [31:0] mul_result;
    logic        mul_done;
    logic        mul_busy;
    logic [31:0] div_result;
    logic        div_done;
    logic        div_busy;

    mul_unit #(
        .WIDTH(32)
    ) u_mul_unit (
        .clk      (clk),
        .rst      (rst),
        .start    (mul_start),
        .op       (funct3),
        .operand_a(rs1_data),
        .operand_b(rs2_data),
        .result   (mul_result),
        .done     (mul_done),
        .busy     (mul_busy)
    );

    div_unit #(
        .WIDTH(32)
    ) u_div_unit (
        .clk     (clk),
        .rst     (rst),
        .start   (div_start),
        .op      (funct3),
        .dividend(rs1_data),
        .divisor (rs2_data),
        .result  (div_result),
        .done    (div_done),
        .busy    (div_busy)
    );

    // Select the active sub-unit's completion and result.
    logic        sub_done;
    logic [31:0] sub_result;
    assign sub_done   = sel_div_q ? div_done   : mul_done;
    assign sub_result = sel_div_q ? div_result : mul_result;

    // Present a stable busy across the accept cycle and the whole run, and a
    // one-cycle done aligned with the valid result.
    assign busy   = running || issue;
    assign done   = running && sub_done;
    assign result = sub_result;

    always_ff @(posedge clk) begin
        if (rst) begin
            running   <= 1'b0;
            sel_div_q <= 1'b0;
        end
        else if (issue) begin
            running   <= 1'b1;
            sel_div_q <= funct3[2];
        end
        else if (running && sub_done) begin
            running   <= 1'b0;
        end
    end

endmodule
