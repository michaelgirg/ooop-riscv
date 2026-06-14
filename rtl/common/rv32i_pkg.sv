package rv32i_pkg;

    localparam int XLEN = 32;
    localparam int NUM_REGISTERS = 32;

    // ALU control values shared by the decoder and ALU.
    typedef enum logic [3:0] {
        ALU_ADD    = 4'd0,
        ALU_SUB    = 4'd1,
        ALU_SLL    = 4'd2,
        ALU_SRL    = 4'd3,
        ALU_SRA    = 4'd4,
        ALU_AND    = 4'd5,
        ALU_OR     = 4'd6,
        ALU_XOR    = 4'd7,
        ALU_SLT    = 4'd8,
        ALU_SLTU   = 4'd9,
        ALU_COPY_B = 4'd10
    } alu_op_t;

    typedef enum logic [2:0] {
        IMM_I = 3'd0,
        IMM_S = 3'd1,
        IMM_B = 3'd2,
        IMM_U = 3'd3,
        IMM_J = 3'd4
    } imm_sel_t;

    typedef enum logic [2:0] {
        BR_NONE = 3'd0,
        BR_EQ   = 3'd1,
        BR_NE   = 3'd2,
        BR_LT   = 3'd3,
        BR_GE   = 3'd4,
        BR_LTU  = 3'd5,
        BR_GEU  = 3'd6
    } branch_op_t;

    typedef enum logic [1:0] {
        WB_ALU = 2'd0,
        WB_MEM = 2'd1,
        WB_PC4 = 2'd2
    } wb_sel_t;

    typedef enum logic [1:0] {
        MEM_BYTE = 2'd0,
        MEM_HALF = 2'd1,
        MEM_WORD = 2'd2
    } mem_size_t;

    // RV32I funct3 encodings used by the data memory.
    localparam logic [2:0] LOAD_BYTE = 3'b000;
    localparam logic [2:0] LOAD_HALF = 3'b001;
    localparam logic [2:0] LOAD_WORD = 3'b010;
    localparam logic [2:0] LOAD_BYTE_U = 3'b100;
    localparam logic [2:0] LOAD_HALF_U = 3'b101;

    localparam logic [2:0] STORE_BYTE = 3'b000;
    localparam logic [2:0] STORE_HALF = 3'b001;
    localparam logic [2:0] STORE_WORD = 3'b010;

    // RV32I major opcodes, ordered as shown in the ISA table.
    localparam logic [6:0] OP_LUI = 7'b0110111;
    localparam logic [6:0] OP_AUIPC = 7'b0010111;
    localparam logic [6:0] OP_JAL = 7'b1101111;
    localparam logic [6:0] OP_JALR = 7'b1100111;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_LOAD = 7'b0000011;
    localparam logic [6:0] OP_STORE = 7'b0100011;
    localparam logic [6:0] OP_IMM = 7'b0010011;
    localparam logic [6:0] OP_REG = 7'b0110011;
    localparam logic [6:0] OP_FENCE = 7'b0001111;
    localparam logic [6:0] OP_SYSTEM = 7'b1110011;

    localparam logic [31:0] INSTRUCTION_NOP = 32'h0000_0013;
    localparam logic [31:0] INSTRUCTION_ECALL = 32'h0000_0073;
    localparam logic [31:0] INSTRUCTION_EBREAK = 32'h0010_0073;
    localparam logic [31:0] INSTRUCTION_FENCE_I = 32'h0000_100f;

endpackage
