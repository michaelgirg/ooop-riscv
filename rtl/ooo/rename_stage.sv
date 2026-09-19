import ooo_pkg::*;

// Single-wide rename and dispatch coordinator.
//
// Owner: Ant
// Depends on Mike: physical_regfile.sv, rename_map.sv, free_list.sv, rob.sv
//
// The output transfer is atomic: the ROB and selected destination queue must
// accept the same instruction in the same cycle. A destination allocation,
// speculative-map update, PRF not-ready update, and branch checkpoint save
// occur only when that dispatch transfer completes.

module rename_stage (
    input logic clk,
    input logic rst,

    input  logic             decoded_valid_i,
    input  var decoded_uop_t decoded_uop_i,
    output logic             decoded_ready_o,

    // Rename-map lookup results for decoded rs1, rs2, and rd.
    output arch_reg_t map_source_1_arch_o,
    output arch_reg_t map_source_2_arch_o,
    output arch_reg_t map_destination_arch_o,
    input  phys_reg_t map_source_1_phys_i,
    input  phys_reg_t map_source_2_phys_i,
    input  phys_reg_t map_stale_destination_phys_i,

    // Physical-register read values and readiness.
    input logic [31:0] prf_source_1_value_i,
    input logic [31:0] prf_source_2_value_i,
    input logic        prf_source_1_ready_i,
    input logic        prf_source_2_ready_i,

    // Candidate destination from the free list.
    input  logic      free_allocate_valid_i,
    input  phys_reg_t free_allocate_phys_i,
    output logic      free_allocate_ready_o,

    // The ROB exposes its next allocation tag before dispatch.
    input var rob_tag_t rob_dispatch_tag_i,

    // Aggregated readiness from the ROB and selected issue/memory queue.
    input  logic                 dispatch_ready_i,
    output logic                 dispatch_valid_o,
    output var dispatch_packet_t dispatch_packet_o,

    // State updates generated only by an accepted dispatch.
    output logic      map_rename_valid_o,
    output arch_reg_t map_rename_arch_o,
    output phys_reg_t map_rename_phys_o,
    output logic      prf_allocate_valid_o,
    output phys_reg_t prf_allocate_phys_o,
    output logic      checkpoint_save_valid_o,
    output rob_tag_t  checkpoint_branch_tag_o
);

    logic needs_destination;
    logic resources_available;
    logic dispatch_fire;

    always_comb begin
        map_source_1_arch_o = decoded_uop_i.rs1_arch;
        map_source_2_arch_o = decoded_uop_i.rs2_arch;
        map_destination_arch_o = decoded_uop_i.rd_arch;

        needs_destination = decoded_uop_i.writes_rd &&
                            (decoded_uop_i.rd_arch != ARCH_ZERO);
        resources_available = dispatch_ready_i &&
                              (!needs_destination || free_allocate_valid_i);

        decoded_ready_o = resources_available;
        dispatch_valid_o = decoded_valid_i &&
                           (!needs_destination || free_allocate_valid_i);
        dispatch_fire = dispatch_valid_o && dispatch_ready_i;

        dispatch_packet_o = DISPATCH_PACKET_EMPTY;
        dispatch_packet_o.uop.decoded = decoded_uop_i;
        dispatch_packet_o.uop.rob_tag = rob_dispatch_tag_i;
        dispatch_packet_o.uop.rs1_phys = decoded_uop_i.uses_rs1
                                         ? map_source_1_phys_i : PHYS_ZERO;
        dispatch_packet_o.uop.rs2_phys = decoded_uop_i.uses_rs2
                                         ? map_source_2_phys_i : PHYS_ZERO;
        dispatch_packet_o.uop.rd_phys = needs_destination
                                        ? free_allocate_phys_i : PHYS_ZERO;
        dispatch_packet_o.uop.stale_rd_phys = needs_destination
                                              ? map_stale_destination_phys_i
                                              : PHYS_ZERO;
        dispatch_packet_o.uop.has_phys_destination = needs_destination;

        dispatch_packet_o.source_1.used = decoded_uop_i.uses_rs1;
        dispatch_packet_o.source_1.ready = !decoded_uop_i.uses_rs1 ||
                                           prf_source_1_ready_i;
        dispatch_packet_o.source_1.tag = decoded_uop_i.uses_rs1
                                         ? map_source_1_phys_i : PHYS_ZERO;
        dispatch_packet_o.source_1.value = decoded_uop_i.uses_rs1
                                           ? prf_source_1_value_i : '0;
        dispatch_packet_o.source_2.used = decoded_uop_i.uses_rs2;
        dispatch_packet_o.source_2.ready = !decoded_uop_i.uses_rs2 ||
                                           prf_source_2_ready_i;
        dispatch_packet_o.source_2.tag = decoded_uop_i.uses_rs2
                                         ? map_source_2_phys_i : PHYS_ZERO;
        dispatch_packet_o.source_2.value = decoded_uop_i.uses_rs2
                                           ? prf_source_2_value_i : '0;

        free_allocate_ready_o = dispatch_fire && needs_destination;
        map_rename_valid_o = dispatch_fire && needs_destination;
        map_rename_arch_o = decoded_uop_i.rd_arch;
        map_rename_phys_o = needs_destination
                            ? free_allocate_phys_i : PHYS_ZERO;
        prf_allocate_valid_o = dispatch_fire && needs_destination;
        prf_allocate_phys_o = needs_destination
                              ? free_allocate_phys_i : PHYS_ZERO;

        checkpoint_save_valid_o = dispatch_fire &&
                                  (decoded_uop_i.control_flow !=
                                   CONTROL_FLOW_NONE);
        checkpoint_branch_tag_o = rob_dispatch_tag_i;
    end

endmodule
