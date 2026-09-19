import ooo_pkg::*;

// Single-wide RV32IM out-of-order core integration shell.
//
// Owner: Together, implemented last
//
// This module contains the OOO core only. Its instruction- and data-cache
// ports intentionally match the CPU sides of the existing icache and dcache,
// allowing the current cache/backing-memory system to be reused unchanged.

module core_ooo (
    input logic clk,
    input logic rst,

    // Existing I-cache CPU-side interface.
    output logic        icache_req_valid_o,
    output logic [31:0] icache_req_addr_o,
    input  logic        icache_resp_valid_i,
    input  logic [31:0] icache_resp_data_i,
    input  logic        icache_resp_fault_i,
    input  logic        icache_stall_i,

    // Existing D-cache CPU-side request interface.
    output logic        dcache_req_valid_o,
    output logic        dcache_req_write_o,
    output logic [31:0] dcache_req_addr_o,
    output logic [31:0] dcache_req_wdata_o,
    output logic [2:0]  dcache_req_funct3_o,
    input  logic        dcache_req_ready_i,

    // Existing D-cache CPU-side response interface.
    output logic        dcache_resp_ready_o,
    input  logic        dcache_resp_valid_i,
    input  logic [31:0] dcache_resp_rdata_i,
    input  logic        dcache_resp_hit_i,
    input  logic        dcache_resp_miss_i,
    input  logic        dcache_resp_fault_i,

    // Minimal machine trap-vector input until the CSR file is added.
    input logic [31:0] trap_target_i,

    output logic [31:0] current_pc_o,
    output logic        halted_o,
    output logic        illegal_instruction_o,
    output logic        instruction_fault_o,
    output logic        data_fault_o,
    output var retire_event_t retire_o
);

    logic frontend_valid;
    decoded_uop_t frontend_uop;
    logic frontend_ready;
    logic frontend_icache_valid;
    logic [31:0] frontend_icache_addr;

    arch_reg_t map_source_1_arch;
    arch_reg_t map_source_2_arch;
    arch_reg_t map_destination_arch;
    phys_reg_t map_source_1_phys;
    phys_reg_t map_source_2_phys;
    phys_reg_t map_stale_phys;
    phys_reg_mask_t committed_phys_mask;
    logic map_rename_valid;
    arch_reg_t map_rename_arch;
    phys_reg_t map_rename_phys;
    logic map_commit_valid;
    arch_reg_t map_commit_arch;
    phys_reg_t map_commit_phys;

    logic [31:0] prf_source_1_value;
    logic [31:0] prf_source_2_value;
    logic prf_source_1_ready;
    logic prf_source_2_ready;
    logic prf_allocate_valid;
    phys_reg_t prf_allocate_phys;

    logic free_allocate_valid;
    phys_reg_t free_allocate_phys;
    logic free_allocate_ready;
    logic free_release_valid;
    phys_reg_t free_release_phys;
    logic free_empty;
    logic free_full;

    logic checkpoint_save_valid;
    rob_tag_t checkpoint_branch_tag;

    logic rename_dispatch_valid;
    dispatch_packet_t rename_dispatch_packet;
    logic rename_dispatch_ready;
    logic destination_ready;
    logic dispatch_to_memory;
    logic dispatch_to_issue;
    logic dispatch_terminal;

    logic rob_dispatch_ready;
    rob_tag_t rob_dispatch_tag;
    logic rob_commit_valid;
    rob_commit_t rob_commit_entry;
    logic rob_commit_ready;
    rob_tag_t rob_head_tag;
    logic rob_empty;
    logic rob_full;
    logic [ROB_INDEX_BITS:0] rob_count;

    logic issue_dispatch_ready;
    logic issue_valid;
    execution_request_t issue_request;
    logic execute_issue_ready;
    logic issue_full;
    logic issue_empty;

    logic memory_dispatch_ready;
    logic memory_full;
    logic memory_empty;

    logic execute_result_valid;
    completion_t execute_result;
    logic execute_result_ready;
    logic memory_result_valid;
    completion_t memory_result;
    logic memory_result_ready;
    result_bus_t result_bus;

    logic branch_valid;
    branch_resolution_t branch_resolution;
    logic branch_ready;
    recovery_event_t recovery;
    logic flush_all;
    logic redirect_valid;
    logic [31:0] redirect_pc;

    logic store_commit_valid;
    rob_tag_t store_commit_tag;
    logic store_commit_done;
    logic store_commit_fault;

    logic trap_valid;
    logic [31:0] trap_pc;
    exception_cause_t trap_cause;
    logic [31:0] trap_value;
    logic halt_request;
    logic trap_taken;
    logic [31:0] observed_trap_pc;
    exception_cause_t observed_trap_cause;
    logic [31:0] observed_trap_value;
    logic halted;

    ooo_frontend u_frontend (
        .clk                (clk),
        .rst                (rst),
        .redirect_valid_i   (redirect_valid),
        .redirect_pc_i      (redirect_pc),
        .decoded_valid_o    (frontend_valid),
        .decoded_uop_o      (frontend_uop),
        .decoded_ready_i    (frontend_ready),
        .icache_req_valid_o (frontend_icache_valid),
        .icache_req_addr_o  (frontend_icache_addr),
        .icache_resp_valid_i(icache_resp_valid_i),
        .icache_resp_data_i (icache_resp_data_i),
        .icache_resp_fault_i(icache_resp_fault_i),
        .icache_stall_i     (icache_stall_i),
        .fetch_pc_o         (current_pc_o)
    );

    assign icache_req_valid_o = frontend_icache_valid && !halted;
    assign icache_req_addr_o = frontend_icache_addr;

    rename_stage u_rename_stage (
        .clk                      (clk),
        .rst                      (rst),
        .decoded_valid_i          (frontend_valid),
        .decoded_uop_i            (frontend_uop),
        .decoded_ready_o          (frontend_ready),
        .map_source_1_arch_o      (map_source_1_arch),
        .map_source_2_arch_o      (map_source_2_arch),
        .map_destination_arch_o   (map_destination_arch),
        .map_source_1_phys_i      (map_source_1_phys),
        .map_source_2_phys_i      (map_source_2_phys),
        .map_stale_destination_phys_i(map_stale_phys),
        .prf_source_1_value_i     (prf_source_1_value),
        .prf_source_2_value_i     (prf_source_2_value),
        .prf_source_1_ready_i     (prf_source_1_ready),
        .prf_source_2_ready_i     (prf_source_2_ready),
        .free_allocate_valid_i    (free_allocate_valid),
        .free_allocate_phys_i     (free_allocate_phys),
        .free_allocate_ready_o    (free_allocate_ready),
        .rob_dispatch_tag_i       (rob_dispatch_tag),
        .dispatch_ready_i         (rename_dispatch_ready),
        .dispatch_valid_o         (rename_dispatch_valid),
        .dispatch_packet_o        (rename_dispatch_packet),
        .map_rename_valid_o       (map_rename_valid),
        .map_rename_arch_o        (map_rename_arch),
        .map_rename_phys_o        (map_rename_phys),
        .prf_allocate_valid_o     (prf_allocate_valid),
        .prf_allocate_phys_o      (prf_allocate_phys),
        .checkpoint_save_valid_o  (checkpoint_save_valid),
        .checkpoint_branch_tag_o  (checkpoint_branch_tag)
    );

    rename_map u_rename_map (
        .clk                         (clk),
        .rst                         (rst),
        .source_1_arch_i             (map_source_1_arch),
        .source_2_arch_i             (map_source_2_arch),
        .destination_arch_i          (map_destination_arch),
        .source_1_phys_o             (map_source_1_phys),
        .source_2_phys_o             (map_source_2_phys),
        .stale_destination_phys_o    (map_stale_phys),
        .committed_phys_in_use_o     (committed_phys_mask),
        .rename_valid_i              (map_rename_valid),
        .rename_arch_i               (map_rename_arch),
        .rename_phys_i               (map_rename_phys),
        .commit_valid_i              (map_commit_valid),
        .commit_arch_i               (map_commit_arch),
        .commit_phys_i               (map_commit_phys),
        .checkpoint_save_valid_i     (checkpoint_save_valid),
        .checkpoint_branch_tag_i     (checkpoint_branch_tag),
        .recover_valid_i             (recovery.valid),
        .recover_branch_tag_i        (recovery.branch_tag),
        .restore_committed_i         (trap_taken)
    );

    physical_regfile u_physical_regfile (
        .clk             (clk),
        .rst             (rst),
        .source_1_tag_i  (map_source_1_phys),
        .source_2_tag_i  (map_source_2_phys),
        .source_1_value_o(prf_source_1_value),
        .source_2_value_o(prf_source_2_value),
        .source_1_ready_o(prf_source_1_ready),
        .source_2_ready_o(prf_source_2_ready),
        .allocate_valid_i(prf_allocate_valid),
        .allocate_tag_i  (prf_allocate_phys),
        .result_i        (result_bus)
    );

    free_list u_free_list (
        .clk                    (clk),
        .rst                    (rst),
        .allocate_valid_o       (free_allocate_valid),
        .allocate_phys_o        (free_allocate_phys),
        .allocate_ready_i       (free_allocate_ready),
        .release_valid_i        (free_release_valid),
        .release_phys_i         (free_release_phys),
        .checkpoint_save_valid_i(checkpoint_save_valid),
        .checkpoint_branch_tag_i(checkpoint_branch_tag),
        .recover_valid_i        (recovery.valid),
        .recover_branch_tag_i   (recovery.branch_tag),
        .rebuild_valid_i        (trap_taken),
        .rebuild_in_use_i       (committed_phys_mask),
        .empty_o                (free_empty),
        .full_o                 (free_full)
    );

    always_comb begin
        dispatch_to_memory =
            (frontend_uop.uop_class == UOP_LOAD) ||
            (frontend_uop.uop_class == UOP_STORE);
        dispatch_terminal = frontend_uop.exception_valid ||
                            frontend_uop.halt;
        dispatch_to_issue = !dispatch_to_memory && !dispatch_terminal;

        if (dispatch_terminal)
            destination_ready = 1'b1;
        else if (dispatch_to_memory)
            destination_ready = memory_dispatch_ready;
        else
            destination_ready = issue_dispatch_ready;

        rename_dispatch_ready = rob_dispatch_ready && destination_ready;
    end

    rob u_rob (
        .clk             (clk),
        .rst             (rst),
        .dispatch_valid_i(rename_dispatch_valid && destination_ready),
        .dispatch_uop_i  (rename_dispatch_packet.uop),
        .dispatch_ready_o(rob_dispatch_ready),
        .dispatch_tag_o  (rob_dispatch_tag),
        .result_i        (result_bus),
        .recovery_i      (recovery),
        .flush_all_i     (flush_all),
        .commit_valid_o  (rob_commit_valid),
        .commit_o        (rob_commit_entry),
        .commit_ready_i  (rob_commit_ready),
        .head_tag_o      (rob_head_tag),
        .empty_o         (rob_empty),
        .full_o          (rob_full),
        .count_o         (rob_count)
    );

    issue_queue u_issue_queue (
        .clk             (clk),
        .rst             (rst),
        .dispatch_valid_i(rename_dispatch_valid && rob_dispatch_ready &&
                          dispatch_to_issue),
        .dispatch_packet_i(rename_dispatch_packet),
        .dispatch_ready_o(issue_dispatch_ready),
        .result_i        (result_bus),
        .rob_head_tag_i  (rob_head_tag),
        .recovery_i      (recovery),
        .flush_all_i     (flush_all),
        .issue_valid_o   (issue_valid),
        .issue_request_o (issue_request),
        .issue_ready_i   (execute_issue_ready),
        .full_o          (issue_full),
        .empty_o         (issue_empty)
    );

    execute_cluster u_execute_cluster (
        .clk             (clk),
        .rst             (rst),
        .issue_valid_i   (issue_valid),
        .issue_request_i (issue_request),
        .issue_ready_o   (execute_issue_ready),
        .rob_head_tag_i  (rob_head_tag),
        .recovery_i      (recovery),
        .flush_all_i     (flush_all),
        .result_valid_o  (execute_result_valid),
        .result_o        (execute_result),
        .result_ready_i  (execute_result_ready),
        .branch_valid_o  (branch_valid),
        .branch_o        (branch_resolution),
        .branch_ready_i  (branch_ready)
    );

    memory_queue u_memory_queue (
        .clk                    (clk),
        .rst                    (rst),
        .dispatch_valid_i       (rename_dispatch_valid &&
                                 rob_dispatch_ready && dispatch_to_memory),
        .dispatch_packet_i      (rename_dispatch_packet),
        .dispatch_ready_o       (memory_dispatch_ready),
        .result_i               (result_bus),
        .rob_head_tag_i         (rob_head_tag),
        .recovery_i             (recovery),
        .flush_all_i            (flush_all),
        .result_valid_o         (memory_result_valid),
        .result_o               (memory_result),
        .result_ready_i         (memory_result_ready),
        .store_commit_valid_i   (store_commit_valid),
        .store_commit_tag_i     (store_commit_tag),
        .store_commit_done_o    (store_commit_done),
        .store_commit_fault_o   (store_commit_fault),
        .dcache_req_valid_o     (dcache_req_valid_o),
        .dcache_req_write_o     (dcache_req_write_o),
        .dcache_req_addr_o      (dcache_req_addr_o),
        .dcache_req_wdata_o     (dcache_req_wdata_o),
        .dcache_req_funct3_o    (dcache_req_funct3_o),
        .dcache_req_ready_i     (dcache_req_ready_i),
        .dcache_resp_ready_o    (dcache_resp_ready_o),
        .dcache_resp_valid_i    (dcache_resp_valid_i),
        .dcache_resp_rdata_i    (dcache_resp_rdata_i),
        .dcache_resp_hit_i      (dcache_resp_hit_i),
        .dcache_resp_miss_i     (dcache_resp_miss_i),
        .dcache_resp_fault_i    (dcache_resp_fault_i),
        .full_o                 (memory_full),
        .empty_o                (memory_empty)
    );

    result_arbiter u_result_arbiter (
        .clk            (clk),
        .rst            (rst),
        .execute_valid_i(execute_result_valid),
        .execute_result_i(execute_result),
        .execute_ready_o(execute_result_ready),
        .memory_valid_i (memory_result_valid),
        .memory_result_i(memory_result),
        .memory_ready_o (memory_result_ready),
        .result_o       (result_bus),
        .result_ready_i (1'b1)
    );

    commit_unit u_commit_unit (
        .clk                 (clk),
        .rst                 (rst),
        .rob_valid_i         (rob_commit_valid),
        .rob_entry_i         (rob_commit_entry),
        .rob_ready_o         (rob_commit_ready),
        .map_commit_valid_o  (map_commit_valid),
        .map_commit_arch_o   (map_commit_arch),
        .map_commit_phys_o   (map_commit_phys),
        .free_release_valid_o(free_release_valid),
        .free_release_phys_o (free_release_phys),
        .store_commit_valid_o(store_commit_valid),
        .store_commit_tag_o  (store_commit_tag),
        .store_commit_done_i (store_commit_done),
        .store_commit_fault_i(store_commit_fault),
        .trap_valid_o        (trap_valid),
        .trap_pc_o           (trap_pc),
        .trap_cause_o        (trap_cause),
        .trap_value_o        (trap_value),
        .halt_o              (halt_request),
        .retire_o            (retire_o)
    );

    ooo_control u_ooo_control (
        .clk          (clk),
        .rst          (rst),
        .branch_i     (branch_resolution),
        .branch_ready_o(branch_ready),
        .trap_valid_i (trap_valid),
        .trap_pc_i    (trap_pc),
        .trap_cause_i (trap_cause),
        .trap_value_i (trap_value),
        .trap_target_i(trap_target_i),
        .halt_i       (halt_request),
        .recovery_o   (recovery),
        .flush_all_o  (flush_all),
        .redirect_valid_o(redirect_valid),
        .redirect_pc_o(redirect_pc),
        .trap_taken_o (trap_taken),
        .trap_pc_o    (observed_trap_pc),
        .trap_cause_o (observed_trap_cause),
        .trap_value_o (observed_trap_value),
        .halted_o     (halted)
    );

    assign halted_o = halted;
    assign illegal_instruction_o = trap_taken &&
        (observed_trap_cause == EXC_ILLEGAL_INSTRUCTION);
    assign instruction_fault_o = trap_taken &&
        ((observed_trap_cause == EXC_INSTRUCTION_ACCESS_FAULT) ||
         (observed_trap_cause == EXC_INSTRUCTION_ADDRESS_MISALIGNED));
    assign data_fault_o = trap_taken &&
        ((observed_trap_cause == EXC_LOAD_ACCESS_FAULT) ||
         (observed_trap_cause == EXC_STORE_ACCESS_FAULT) ||
         (observed_trap_cause == EXC_LOAD_ADDRESS_MISALIGNED) ||
         (observed_trap_cause == EXC_STORE_ADDRESS_MISALIGNED));

endmodule
