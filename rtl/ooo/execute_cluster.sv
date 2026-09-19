import ooo_pkg::*;

// ALU, branch, jump, and RV32M execution cluster.
//
// Owner: Ant
// Depends on: issue_queue.sv and result_arbiter.sv
//
// ALU/branch results are short latency. MUL/DIV may remain active while newer
// ALU instructions execute. Every producer must hold a completed result until
// the result arbiter accepts it. Recovery must cancel a younger long-latency
// operation or prevent its eventual completion from becoming visible.

module execute_cluster (
    input logic clk,
    input logic rst,

    input  logic                   issue_valid_i,
    input  var execution_request_t issue_request_i,
    output logic                   issue_ready_o,

    input var rob_tag_t        rob_head_tag_i,
    input var recovery_event_t recovery_i,
    input logic flush_all_i,

    // Completion producer presented to the common result arbiter.
    output logic            result_valid_o,
    output var completion_t result_o,
    input  logic            result_ready_i,

    // Branch resolution is accepted separately so redirect recovery does not
    // wait behind an unrelated result-bus completion.
    output logic                   branch_valid_o,
    output var branch_resolution_t branch_o,
    input  logic                   branch_ready_i
);

    completion_t result_q;
    branch_resolution_t branch_q;

    execution_request_t muldiv_request_q;
    logic muldiv_active_q;
    logic muldiv_squashed_q;
    logic [31:0] muldiv_result;
    logic muldiv_busy;
    logic muldiv_done;
    logic muldiv_start;
    logic muldiv_result_ready;

    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [31:0] alu_result;
    logic alu_zero;
    logic branch_taken;
    logic [31:0] control_target;
    logic control_taken;
    logic control_mispredicted;
    logic issue_fire;
    logic short_operation;
    logic current_is_younger;
    logic muldiv_is_younger;

    alu u_alu (
        .op_a  (operand_a),
        .op_b  (operand_b),
        .alu_op(issue_request_i.uop.decoded.alu_op),
        .result(alu_result),
        .zero  (alu_zero)
    );

    branch_unit u_branch_unit (
        .rs1_data   (issue_request_i.source_1_value),
        .rs2_data   (issue_request_i.source_2_value),
        .branch_op  (issue_request_i.uop.decoded.branch_op),
        .branch_taken(branch_taken)
    );

    muldiv_unit u_muldiv_unit (
        .clk         (clk),
        .rst         (rst),
        .in_valid    (muldiv_start),
        .funct3      (issue_request_i.uop.decoded.muldiv_op),
        .rs1_data    (issue_request_i.source_1_value),
        .rs2_data    (issue_request_i.source_2_value),
        .result_ready(muldiv_result_ready),
        .result      (muldiv_result),
        .busy        (muldiv_busy),
        .done        (muldiv_done)
    );

    always_comb begin
        case (issue_request_i.uop.decoded.operand_a_sel)
            OPERAND_A_PC: operand_a = issue_request_i.uop.decoded.pc;
            OPERAND_A_ZERO: operand_a = '0;
            default: operand_a = issue_request_i.source_1_value;
        endcase

        case (issue_request_i.uop.decoded.operand_b_sel)
            OPERAND_B_IMM: operand_b =
                issue_request_i.uop.decoded.immediate;
            OPERAND_B_FOUR: operand_b = 32'd4;
            default: operand_b = issue_request_i.source_2_value;
        endcase

        control_taken = 1'b0;
        control_target = issue_request_i.uop.decoded.pc + 32'd4;
        if (issue_request_i.uop.decoded.control_flow ==
            CONTROL_FLOW_BRANCH) begin
            control_taken = branch_taken;
            control_target = issue_request_i.uop.decoded.pc +
                             issue_request_i.uop.decoded.immediate;
        end else if (issue_request_i.uop.decoded.control_flow ==
                     CONTROL_FLOW_DIRECT) begin
            control_taken = 1'b1;
            control_target = issue_request_i.uop.decoded.pc +
                             issue_request_i.uop.decoded.immediate;
        end else if (issue_request_i.uop.decoded.control_flow ==
                     CONTROL_FLOW_INDIRECT) begin
            control_taken = 1'b1;
            control_target = (issue_request_i.source_1_value +
                              issue_request_i.uop.decoded.immediate) &
                             32'hffff_fffe;
        end

        control_mispredicted =
            (control_taken != issue_request_i.uop.decoded.prediction.taken) ||
            (control_taken &&
             (control_target !=
              issue_request_i.uop.decoded.prediction.target));

        short_operation =
            (issue_request_i.uop.decoded.uop_class != UOP_MULDIV);
        current_is_younger = recovery_i.valid &&
            rob_is_younger(issue_request_i.uop.rob_tag,
                           recovery_i.branch_tag, rob_head_tag_i);
        muldiv_is_younger = recovery_i.valid && muldiv_active_q &&
            rob_is_younger(muldiv_request_q.uop.rob_tag,
                           recovery_i.branch_tag, rob_head_tag_i);

        // A short operation needs a result slot. Control flow additionally
        // needs the independent branch slot. MUL/DIV may run alongside ALU
        // work, but an arriving MUL/DIV completion gets priority this cycle.
        issue_ready_o = !rst && !recovery_i.valid && !flush_all_i &&
                        (!result_q.valid || result_ready_i) &&
                        !muldiv_done &&
                        ((issue_request_i.uop.decoded.control_flow ==
                          CONTROL_FLOW_NONE) ||
                         !branch_q.valid || branch_ready_i) &&
                        ((issue_request_i.uop.decoded.uop_class != UOP_MULDIV) ||
                         !muldiv_active_q);
        issue_fire = issue_valid_i && issue_ready_o;
        muldiv_start = issue_fire && !short_operation;

        result_valid_o = result_q.valid;
        result_o = result_q;
        branch_valid_o = branch_q.valid;
        branch_o = branch_q;

        // Consume a completed squashed operation without exposing it. A live
        // completion may replace a result accepted by the arbiter this cycle.
        muldiv_result_ready = muldiv_done &&
            (muldiv_squashed_q || muldiv_is_younger ||
             !result_q.valid || result_ready_i);
    end

    always_ff @(posedge clk) begin : execute_state
        completion_t completion;
        branch_resolution_t resolution;

        if (rst) begin
            result_q <= COMPLETION_EMPTY;
            branch_q <= BRANCH_RESOLUTION_NONE;
            muldiv_request_q <= EXECUTION_REQUEST_EMPTY;
            muldiv_active_q <= 1'b0;
            muldiv_squashed_q <= 1'b0;
        end else if (flush_all_i) begin
            result_q <= COMPLETION_EMPTY;
            branch_q <= BRANCH_RESOLUTION_NONE;
            if (muldiv_active_q)
                muldiv_squashed_q <= 1'b1;
        end else begin
            if (result_q.valid && result_ready_i)
                result_q <= COMPLETION_EMPTY;
            if (branch_q.valid && branch_ready_i)
                branch_q <= BRANCH_RESOLUTION_NONE;

            if (recovery_i.valid) begin
                if (result_q.valid &&
                    rob_is_younger(result_q.rob_tag, recovery_i.branch_tag,
                                   rob_head_tag_i)) begin
                    result_q <= COMPLETION_EMPTY;
                end
                if (branch_q.valid &&
                    rob_is_younger(branch_q.branch_tag,
                                   recovery_i.branch_tag, rob_head_tag_i)) begin
                    branch_q <= BRANCH_RESOLUTION_NONE;
                end
                if (muldiv_is_younger)
                    muldiv_squashed_q <= 1'b1;
            end

            if (issue_fire && short_operation && !current_is_younger) begin
                completion = COMPLETION_EMPTY;
                completion.valid = 1'b1;
                completion.rob_tag = issue_request_i.uop.rob_tag;
                completion.writes_phys =
                    issue_request_i.uop.has_phys_destination;
                completion.rd_phys = issue_request_i.uop.rd_phys;

                if (issue_request_i.uop.decoded.uop_class == UOP_JUMP)
                    completion.result = issue_request_i.uop.decoded.pc + 32'd4;
                else
                    completion.result = alu_result;

                if (issue_request_i.uop.decoded.control_flow !=
                    CONTROL_FLOW_NONE) begin
                    completion.branch_valid = 1'b1;
                    completion.branch_taken = control_taken;
                    completion.branch_mispredicted = control_mispredicted;
                    completion.branch_target = control_target;

                    resolution = BRANCH_RESOLUTION_NONE;
                    resolution.valid = 1'b1;
                    resolution.branch_tag = issue_request_i.uop.rob_tag;
                    resolution.taken = control_taken;
                    resolution.mispredicted = control_mispredicted;
                    resolution.target = control_taken
                                        ? control_target
                                        : issue_request_i.uop.decoded.pc + 32'd4;
                    branch_q <= resolution;
                end

                result_q <= completion;
            end

            if (muldiv_start) begin
                muldiv_request_q <= issue_request_i;
                muldiv_active_q <= 1'b1;
                muldiv_squashed_q <= 1'b0;
            end

            if (muldiv_done && muldiv_result_ready && muldiv_active_q) begin
                if (!muldiv_squashed_q && !muldiv_is_younger) begin
                    completion = COMPLETION_EMPTY;
                    completion.valid = 1'b1;
                    completion.rob_tag = muldiv_request_q.uop.rob_tag;
                    completion.writes_phys =
                        muldiv_request_q.uop.has_phys_destination;
                    completion.rd_phys = muldiv_request_q.uop.rd_phys;
                    completion.result = muldiv_result;
                    result_q <= completion;
                end
                muldiv_active_q <= 1'b0;
                muldiv_squashed_q <= 1'b0;
            end
        end
    end

endmodule
