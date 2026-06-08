//Instruction Memroy

// Mem is word organized, but addresses are byte addresses
// This makes it so address bit [1:0] are omitted

// Note:
// Each RV32I instruction is 4 bytes, so byte addresses 0, 4, 8, 12 select mem[0], mem[1], mem[2], mem[3].
// Since it a 4-byte aligned instruction the last two bits are always 00 since we fetch whole instructions

// address[31:2]  // tells us which instruction: mem[0], mem[1], mem[2]
// address[1:0]   // tells us which byte inside that instruction

module imem #(
    parameter int WORDS = 256,  // 1KB = 1024 Bytes / 4 Bytes = 256 words
    parameter string HEX_FILE = ""
) (
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    // memory has WORDS entries and each entry is 32 bits wide:
    // memory[0]
    // memory[1]
    // memory[2]
    // ...
    // memory[255]
    logic [31:0] mem[0:WORDS-1];


    initial begin
        if (HEX_FILE != "") begin
            $readmemh(HEX_FILE, mem);
        end
    end

    always_comb begin
        instruction = 32'h0000_0013;  //addi x0, x0, 0 (this is a NOP)
        // This is here so if the addr is out of range it will recieve this instruction instead of garabage

        if (address[31:2] < WORDS) begin  //checks if within range
            instruction = mem[address[31:2]];  //converts byte addr into word index
        end

    end

endmodule
