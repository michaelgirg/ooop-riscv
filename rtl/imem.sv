// Word-organized instruction memory with byte-addressed inputs.
// Uninitialized and out-of-range locations return the canonical RV32I NOP.

module imem #(
    parameter int WORDS = 256,  // 1KB = 1024 Bytes / 4 Bytes = 256 words
    parameter string HEX_FILE = ""
) (
    input  logic [31:0] address,
    output logic [31:0] instruction,
    output logic        access_fault
);
    import rv32i_pkg::*;

    logic [31:0] mem[0:WORDS-1];

    initial begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] = INSTRUCTION_NOP;
        end

        if (HEX_FILE != "") begin
            $readmemh(HEX_FILE, mem);
        end
    end

    always_comb begin
        instruction = INSTRUCTION_NOP;
        access_fault = (address[1:0] != 2'b00) || (address[31:2] >= WORDS);

        if (!access_fault) begin
            instruction = mem[address[31:2]];
        end
    end

endmodule
