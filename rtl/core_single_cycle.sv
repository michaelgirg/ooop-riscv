// Single-cycle RV32I core.
//
// Every instruction is fetched, decoded, executed, and prepared for
// architectural update within one clock period. The PC, register file, and
// data-memory stores update on the rising clock edge.

module core_single_cycle #(
    parameter int IMEM_WORDS = 256,
    parameter int DMEM_WORDS = 1024,
    parameter string IMEM_HEX = "",
    parameter string DMEM_HEX = ""
) (
    input  logic        clk_i,
    input  logic        rst_i,
    output logic [31:0] current_pc_o,
    output logic [31:0] instruction_o,
    output logic        halted_o,
    output logic        illegal_instruction_o
);
    import rv32i_pkg::*;

    logic [31:0] current_pc;
    logic [31:0] next_pc;
    logic [31:0] pc_plus_four;
    logic [31:0] instruction;
    logic [31:0] immediate;

    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [4:0] rd_addr;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    logic [3:0] alu_op;
    logic [2:0] imm_sel;
    logic [2:0] branch_op;
    logic [1:0] wb_sel;
    logic [1:0] mem_size;
    logic       reg_write;
    logic       alu_src_imm;
    logic       alu_src_pc;
    logic       mem_read;
    logic       mem_write;
    logic       load_unsigned;
    logic       jump;
    logic       jalr;
    logic       halt;
    logic       illegal;

    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic        branch_taken;
    logic [2:0]  memory_funct3;
    logic [31:0] memory_read_data;
    logic [31:0] writeback_data;
    logic        architectural_enable;

    assign current_pc_o = current_pc;
    assign instruction_o = instruction;
    assign halted_o = halt;
    assign illegal_instruction_o = illegal;

    assign pc_plus_four = current_pc + 32'd4;
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign rd_addr = instruction[11:7];

    assign alu_operand_a = alu_src_pc ? current_pc : rs1_data;
    assign alu_operand_b = alu_src_imm ? immediate : rs2_data;

    // The decoder separates memory width and load signedness. Together they
    // recreate the instruction funct3 value consumed by dmem.
    assign memory_funct3 = {load_unsigned, mem_size};

    // Reset, halt, and illegal instructions cannot change architectural state.
    assign architectural_enable = !rst_i && !halt && !illegal;

    always_comb begin
        next_pc = pc_plus_four;

        if (branch_taken) begin
            next_pc = current_pc + immediate;
        end

        if (jump) begin
            if (jalr) begin
                next_pc = alu_result & 32'hffff_fffe;
            end else begin
                next_pc = current_pc + immediate;
            end
        end
    end

    always_comb begin
        case (wb_sel)
            WB_ALU: writeback_data = alu_result;
            WB_MEM: writeback_data = memory_read_data;
            WB_PC4: writeback_data = pc_plus_four;
            default: writeback_data = '0;
        endcase
    end

    pc u_pc (
        .clk     (clk_i),
        .rst     (rst_i),
        .en      (!halt && !illegal),
        .next_pc (next_pc),
        .pc      (current_pc)
    );

    imem #(
        .WORDS    (IMEM_WORDS),
        .HEX_FILE (IMEM_HEX)
    ) u_imem (
        .address     (current_pc),
        .instruction (instruction)
    );

    decoder u_decoder (
        .instruction  (instruction),
        .alu_op       (alu_op),
        .imm_sel      (imm_sel),
        .branch_op    (branch_op),
        .wb_sel       (wb_sel),
        .mem_size     (mem_size),
        .reg_write    (reg_write),
        .alu_src_imm  (alu_src_imm),
        .alu_src_pc   (alu_src_pc),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .load_unsigned(load_unsigned),
        .jump         (jump),
        .jalr         (jalr),
        .halt         (halt),
        .illegal      (illegal)
    );

    imm_gen u_imm_gen (
        .instruction (instruction),
        .imm_sel     (imm_sel),
        .immediate   (immediate)
    );

    regfile u_regfile (
        .clk      (clk_i),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .rd_addr  (rd_addr),
        .rd_data  (writeback_data),
        .we       (reg_write && architectural_enable)
    );

    alu u_alu (
        .op_a   (alu_operand_a),
        .op_b   (alu_operand_b),
        .alu_op (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    branch_unit u_branch_unit (
        .rs1_data     (rs1_data),
        .rs2_data     (rs2_data),
        .branch_op    (branch_op),
        .branch_taken (branch_taken)
    );

    dmem #(
        .DEPTH    (DMEM_WORDS),
        .MEM_INIT (DMEM_HEX)
    ) u_dmem (
        .clk       (clk_i),
        .addr      (alu_result),
        .wr_data   (rs2_data),
        .funct3    (memory_funct3),
        .mem_write (mem_write && architectural_enable),
        .rd_data   (memory_read_data)
    );

endmodule
