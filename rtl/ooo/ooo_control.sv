import ooo_pkg::*;

// Global redirect, branch recovery, precise trap, and halt control.
//
// Owner: Together
// Depends on: execute_cluster.sv, commit_unit.sv, and all recovery consumers
//
// Priority is precise trap, halt, then branch misprediction. A branch recovery
// preserves the branch and older work. A precise trap flushes all speculative
// state and redirects to trap_target_i after the faulting head instruction has
// been handled by commit.

module ooo_control (
    input logic clk,
    input logic rst,

    input  var branch_resolution_t branch_i,
    output logic                   branch_ready_o,

    input logic             trap_valid_i,
    input logic [31:0]      trap_pc_i,
    input exception_cause_t trap_cause_i,
    input logic [31:0]      trap_value_i,
    input logic [31:0]      trap_target_i,
    input logic             halt_i,

    output var recovery_event_t recovery_o,
    output logic                flush_all_o,
    output logic                redirect_valid_o,
    output logic [31:0]         redirect_pc_o,

    output logic             trap_taken_o,
    output logic [31:0]      trap_pc_o,
    output exception_cause_t trap_cause_o,
    output logic [31:0]      trap_value_o,
    output logic             halted_o
);

    logic halted_q;

    always_comb begin
        recovery_o = RECOVERY_EVENT_NONE;
        flush_all_o = 1'b0;
        redirect_valid_o = 1'b0;
        redirect_pc_o = '0;
        branch_ready_o = !rst && !halted_q && !trap_valid_i && !halt_i;

        trap_taken_o = 1'b0;
        trap_pc_o = trap_pc_i;
        trap_cause_o = trap_cause_i;
        trap_value_o = trap_value_i;
        halted_o = halted_q;

        if (!rst && !halted_q) begin
            if (trap_valid_i) begin
                flush_all_o = 1'b1;
                redirect_valid_o = 1'b1;
                redirect_pc_o = trap_target_i;
                trap_taken_o = 1'b1;
            end else if (halt_i) begin
                // Redirect is asserted only to clear the frontend buffer. The
                // sticky halted state prevents another fetch from escaping.
                flush_all_o = 1'b1;
                redirect_valid_o = 1'b1;
                redirect_pc_o = '0;
            end else if (branch_i.valid && branch_i.mispredicted) begin
                recovery_o.valid = 1'b1;
                recovery_o.branch_tag = branch_i.branch_tag;
                recovery_o.redirect_pc = branch_i.target;
                redirect_valid_o = 1'b1;
                redirect_pc_o = branch_i.target;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst)
            halted_q <= 1'b0;
        else if (halt_i)
            halted_q <= 1'b1;
    end

endmodule
