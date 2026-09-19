import ooo_pkg::*;
import rv32i_pkg::*;

// Single-instruction fetch and decode frontend.
//
// Owner: Ant
// Independent first task: yes
//
// Version one predicts every conditional branch as not taken. The frontend
// must hold a fetched/decoded instruction until rename accepts it and must
// discard wrong-path buffered work when redirect_valid_i is asserted.

module ooo_frontend (
    input logic clk,
    input logic rst,

    input logic        redirect_valid_i,
    input logic [31:0] redirect_pc_i,

    output logic             decoded_valid_o,
    output var decoded_uop_t decoded_uop_o,
    input  logic             decoded_ready_i,

    // Existing I-cache CPU-side interface.
    output logic        icache_req_valid_o,
    output logic [31:0] icache_req_addr_o,
    input  logic        icache_resp_valid_i,
    input  logic [31:0] icache_resp_data_i,
    input  logic        icache_resp_fault_i,
    input  logic        icache_stall_i,

    output logic [31:0] fetch_pc_o
);

    decoded_uop_t decoded_q;
    logic [31:0] pc_q;

    logic [3:0] decode_alu_op;
    logic [2:0] decode_imm_sel;
    logic [2:0] decode_branch_op;
    logic [1:0] decode_wb_sel;
    logic [1:0] decode_mem_size;
    muldiv_op_t decode_muldiv_op;
    logic decode_reg_write;
    logic decode_alu_src_imm;
    logic decode_alu_src_pc;
    logic decode_mem_read;
    logic decode_mem_write;
    logic decode_load_unsigned;
    logic decode_jump;
    logic decode_jalr;
    logic decode_is_muldiv;
    logic decode_halt;
    logic decode_illegal;
    logic [31:0] decode_immediate;

    logic buffer_accept;
    logic response_accept;

    decoder u_decoder (
        .instruction   (icache_resp_data_i),
        .alu_op        (decode_alu_op),
        .imm_sel       (decode_imm_sel),
        .branch_op     (decode_branch_op),
        .wb_sel        (decode_wb_sel),
        .mem_size      (decode_mem_size),
        .muldiv_op     (decode_muldiv_op),
        .reg_write     (decode_reg_write),
        .alu_src_imm   (decode_alu_src_imm),
        .alu_src_pc    (decode_alu_src_pc),
        .mem_read      (decode_mem_read),
        .mem_write     (decode_mem_write),
        .load_unsigned (decode_load_unsigned),
        .jump          (decode_jump),
        .jalr          (decode_jalr),
        .is_muldiv     (decode_is_muldiv),
        .halt          (decode_halt),
        .illegal       (decode_illegal)
    );

    imm_gen u_imm_gen (
        .instruction(icache_resp_data_i),
        .imm_sel    (decode_imm_sel),
        .immediate  (decode_immediate)
    );

    always_comb begin
        decoded_valid_o = decoded_q.valid;
        decoded_uop_o = decoded_q;
        fetch_pc_o = pc_q;

        buffer_accept = decoded_q.valid && decoded_ready_i;

        // The cache has no request-ready signal. Keep the request and address
        // stable until it returns a response. When rename consumes the buffer,
        // the already-advanced pc_q may fetch the following instruction.
        icache_req_valid_o = !rst && !redirect_valid_i &&
                             (!decoded_q.valid || buffer_accept);
        icache_req_addr_o = pc_q;
        response_accept = icache_req_valid_o && icache_resp_valid_i &&
                          !icache_stall_i;
    end

    always_ff @(posedge clk) begin : frontend_state
        decoded_uop_t next_uop;
        logic [6:0] opcode;

        if (rst) begin
            pc_q <= '0;
            decoded_q <= DECODED_UOP_EMPTY;
        end else if (redirect_valid_i) begin
            // Redirect wins over a response returning for the old path.
            pc_q <= redirect_pc_i;
            decoded_q <= DECODED_UOP_EMPTY;
        end else begin
            if (buffer_accept)
                decoded_q <= DECODED_UOP_EMPTY;

            if (response_accept) begin
                opcode = icache_resp_data_i[6:0];
                next_uop = DECODED_UOP_EMPTY;
                next_uop.valid = 1'b1;
                next_uop.pc = pc_q;
                next_uop.instruction = icache_resp_data_i;
                next_uop.rs1_arch = arch_reg_t'(icache_resp_data_i[19:15]);
                next_uop.rs2_arch = arch_reg_t'(icache_resp_data_i[24:20]);
                next_uop.rd_arch = arch_reg_t'(icache_resp_data_i[11:7]);
                next_uop.immediate = decode_immediate;
                next_uop.alu_op = alu_op_t'(decode_alu_op);
                next_uop.muldiv_op = decode_muldiv_op;
                next_uop.branch_op = branch_op_t'(decode_branch_op);
                next_uop.wb_sel = wb_sel_t'(decode_wb_sel);
                next_uop.mem_size = mem_size_t'(decode_mem_size);
                next_uop.load_unsigned = decode_load_unsigned;
                next_uop.writes_rd = decode_reg_write &&
                                     (icache_resp_data_i[11:7] != 5'd0);
                next_uop.uses_rs1 = (opcode == OP_JALR) ||
                                    (opcode == OP_BRANCH) ||
                                    (opcode == OP_LOAD) ||
                                    (opcode == OP_STORE) ||
                                    (opcode == OP_IMM) ||
                                    (opcode == OP_REG);
                next_uop.uses_rs2 = (opcode == OP_BRANCH) ||
                                    (opcode == OP_STORE) ||
                                    (opcode == OP_REG);
                next_uop.operand_a_sel = decode_alu_src_pc
                                         ? OPERAND_A_PC : OPERAND_A_RS1;
                next_uop.operand_b_sel = decode_alu_src_imm
                                         ? OPERAND_B_IMM : OPERAND_B_RS2;
                next_uop.prediction.valid = 1'b1;
                next_uop.prediction.taken = 1'b0;
                next_uop.prediction.target = pc_q + 32'd4;

                if (decode_mem_read)
                    next_uop.uop_class = UOP_LOAD;
                else if (decode_mem_write)
                    next_uop.uop_class = UOP_STORE;
                else if (decode_is_muldiv)
                    next_uop.uop_class = UOP_MULDIV;
                else if (opcode == OP_BRANCH)
                    next_uop.uop_class = UOP_BRANCH;
                else if (decode_jump)
                    next_uop.uop_class = UOP_JUMP;
                else if (opcode == OP_FENCE)
                    next_uop.uop_class = UOP_FENCE;
                else if (opcode == OP_SYSTEM)
                    next_uop.uop_class = UOP_SYSTEM;
                else
                    next_uop.uop_class = UOP_ALU;

                if (opcode == OP_BRANCH)
                    next_uop.control_flow = CONTROL_FLOW_BRANCH;
                else if (decode_jump && decode_jalr)
                    next_uop.control_flow = CONTROL_FLOW_INDIRECT;
                else if (decode_jump)
                    next_uop.control_flow = CONTROL_FLOW_DIRECT;
                else
                    next_uop.control_flow = CONTROL_FLOW_NONE;

                next_uop.halt = decode_halt && !icache_resp_fault_i;
                next_uop.exception_valid = icache_resp_fault_i ||
                                           decode_illegal;
                if (icache_resp_fault_i) begin
                    next_uop.exception_cause =
                        EXC_INSTRUCTION_ACCESS_FAULT;
                    next_uop.exception_value = pc_q;
                    next_uop.writes_rd = 1'b0;
                    next_uop.halt = 1'b0;
                end else if (decode_illegal) begin
                    next_uop.exception_cause = EXC_ILLEGAL_INSTRUCTION;
                    next_uop.exception_value = icache_resp_data_i;
                    next_uop.writes_rd = 1'b0;
                end

                decoded_q <= next_uop;
                pc_q <= pc_q + 32'd4;
            end
        end
    end

endmodule
