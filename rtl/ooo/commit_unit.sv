import ooo_pkg::*;

// In-order retirement and precise architectural side-effect controller.
//
// Depends on: rob.sv and the store-commit side of memory_queue.sv
//
// Normal register instructions commit the rename map and release their stale
// physical destination. Stores wait for the memory queue to report that the
// D-cache transaction completed. Faulting instructions retire no side effects
// and request a precise trap using their own PC/cause/value.

module commit_unit (
    input logic clk,
    input logic rst,

    input  logic          rob_valid_i,
    input  var rob_commit_t rob_entry_i,
    output logic          rob_ready_o,

    // Committed-map update and stale-register release.
    output logic      map_commit_valid_o,
    output arch_reg_t map_commit_arch_o,
    output phys_reg_t map_commit_phys_o,
    output logic      free_release_valid_o,
    output phys_reg_t free_release_phys_o,

    // Stores become visible only through this retirement handshake.
    output logic     store_commit_valid_o,
    output rob_tag_t store_commit_tag_o,
    input  logic     store_commit_done_i,
    input  logic     store_commit_fault_i,

    // Precise trap and halt requests are consumed by ooo_control.sv.
    output logic             trap_valid_o,
    output logic [31:0]      trap_pc_o,
    output exception_cause_t trap_cause_o,
    output logic [31:0]      trap_value_o,
    output logic             halt_o,

    output var retire_event_t retire_o
);

    logic retire_now;
    logic retire_exception;
    logic retire_store;
    exception_cause_t selected_exception_cause;
    logic [31:0] selected_exception_value;

    // The ROB holds its head stable until rob_ready_o is asserted, so the store
    // request can be held without another payload register in this block.
    always_comb begin
        rob_ready_o = 1'b0;

        map_commit_valid_o = 1'b0;
        map_commit_arch_o = ARCH_ZERO;
        map_commit_phys_o = PHYS_ZERO;
        free_release_valid_o = 1'b0;
        free_release_phys_o = PHYS_ZERO;

        store_commit_valid_o = 1'b0;
        store_commit_tag_o = '0;

        trap_valid_o = 1'b0;
        trap_pc_o = '0;
        trap_cause_o = EXC_ILLEGAL_INSTRUCTION;
        trap_value_o = '0;
        halt_o = 1'b0;
        retire_o = RETIRE_EVENT_EMPTY;

        retire_now = 1'b0;
        retire_exception = 1'b0;
        retire_store = 1'b0;
        selected_exception_cause = EXC_ILLEGAL_INSTRUCTION;
        selected_exception_value = '0;

        if (!rst && rob_valid_i) begin
            store_commit_tag_o = rob_entry_i.rob_tag;

            // An exception already recorded in the ROB is older than any
            // normal side effect this instruction could otherwise produce.
            if (rob_entry_i.exception_valid) begin
                retire_now = 1'b1;
                retire_exception = 1'b1;
                selected_exception_cause = rob_entry_i.exception_cause;
                selected_exception_value = rob_entry_i.exception_value;
            end else if (rob_entry_i.uop_class == UOP_STORE) begin
                store_commit_valid_o = 1'b1;

                // A fault response wins if done and fault are presented
                // together. The memory system must not make the store visible.
                if (store_commit_fault_i) begin
                    retire_now = 1'b1;
                    retire_exception = 1'b1;
                    selected_exception_cause = EXC_STORE_ACCESS_FAULT;
                    selected_exception_value = rob_entry_i.memory_address;
                end else if (store_commit_done_i) begin
                    retire_now = 1'b1;
                    retire_store = 1'b1;
                end
            end else begin
                retire_now = 1'b1;
            end

            rob_ready_o = retire_now;

            if (retire_now) begin
                retire_o.valid = 1'b1;
                retire_o.pc = rob_entry_i.pc;
                retire_o.instruction = rob_entry_i.instruction;
                retire_o.halt = rob_entry_i.halt && !retire_exception;

                if (retire_exception) begin
                    retire_o.exception_valid = 1'b1;
                    retire_o.exception_cause = selected_exception_cause;
                    retire_o.exception_value = selected_exception_value;

                    trap_valid_o = 1'b1;
                    trap_pc_o = rob_entry_i.pc;
                    trap_cause_o = selected_exception_cause;
                    trap_value_o = selected_exception_value;
                end else if (retire_store) begin
                    retire_o.store_valid = 1'b1;
                    retire_o.store_address = rob_entry_i.memory_address;
                    retire_o.store_data = rob_entry_i.store_data;
                    retire_o.store_size = rob_entry_i.mem_size;
                end else if (!rob_entry_i.halt && rob_entry_i.writes_rd &&
                             (rob_entry_i.rd_arch != ARCH_ZERO)) begin
                    map_commit_valid_o = 1'b1;
                    map_commit_arch_o = rob_entry_i.rd_arch;
                    map_commit_phys_o = rob_entry_i.rd_phys;
                    free_release_valid_o =
                        (rob_entry_i.stale_rd_phys != PHYS_ZERO);
                    free_release_phys_o = rob_entry_i.stale_rd_phys;

                    retire_o.writes_rd = 1'b1;
                    retire_o.rd_arch = rob_entry_i.rd_arch;
                    retire_o.rd_value = rob_entry_i.result;
                end

                halt_o = rob_entry_i.halt && !retire_exception;
            end
        end
    end

endmodule
