//every module imports this hopefully LOL

//if using iverilog, make sure to compile this first

package rv32i_pkg;

    //21 RV32-I Instructions (ALU operations)-------------------------

    typedef enum logic [3:0] {
        ALU_ADD  = 4'h0,  //add duh
        ALU_SLL  = 4'h1,  //shift left logical
        ALU_SLT  = 4'h2,  //set if less than
        ALU_SLTU = 4'h3,  //set if less than unsigned
        ALU_XOR  = 4'h4,  //xor
        ALU_SRL  = 4'h5,  //shift right logical
        ALU_OR   = 4'h6,  //or
        ALU_AND  = 4'h7,  //and
        ALU_SUB  = 4'h8,  //sub
        ALU_SRA  = 4'h9   //shift right arithmetic

    } alu_op_t;

    //Actual opcodes

    localparam logic [6:0] OP_LUI = 7'b0110111,  //U-type
    OP_AUIPC = 7'b0010111,  //U-type
    OP_JAL = 7'b1101111,  //J-type
    OP_JALR = 7'b1100111,  //I-type
    OP_BRANCH = 7'b1100011,  //B-type  (BEQ BNE BLT BGE BLTU BGEU)
    OP_LOAD = 7'b0000011,  //I-type  (LB LH LW LBU LHU)
    OP_STORE = 7'b0100011,  //S-type  (SB SH SW)
    OP_IMM = 7'b0010011,  //I-type  (ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI)
    OP_REG = 7'b0110011,  //R-type  (ADD SUB SLL SLT SLTU XOR SRL SRA OR AND)
    OP_FENCE = 7'b0001111,  //I-type  (FENCE FENCE.I — NOP in single-core)
    OP_SYSTEM = 7'b1110011;  //I-type  (ECALL EBREAK CSR* — trap-to-halt)


    //memory widths for dmem
    /*
    000 (LB and SB sign-extend)
    001 (LH and SH sign-extend)
    010 (LW and SW)
    100 (LBU zero-extend)
    101 (LHU zero-extend)
    
    */

    localparam logic[2:0]
    MEM_BYTE = 3'b000,
    MEM_HALF  = 3'b001,
    MEM_WORD  = 3'b010,
    MEM_BYTEU = 3'b100,
    MEM_HALFU = 3'b101;

endpackage
