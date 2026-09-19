`timescale 1ns/1ps

module rename_stage_tb;
    import ooo_pkg::*;

    logic clk, rst, decoded_valid, decoded_ready;
    decoded_uop_t decoded;
    arch_reg_t map_rs1, map_rs2, map_rd;
    phys_reg_t rs1_phys, rs2_phys, stale_phys;
    logic [31:0] rs1_value, rs2_value;
    logic rs1_ready, rs2_ready, free_valid, free_ready;
    phys_reg_t free_phys;
    rob_tag_t rob_tag;
    logic dispatch_ready, dispatch_valid;
    dispatch_packet_t packet;
    logic map_rename_valid, prf_allocate_valid, checkpoint_valid;
    arch_reg_t map_rename_arch;
    phys_reg_t map_rename_phys, prf_allocate_phys;
    rob_tag_t checkpoint_tag;
    int errors;

    rename_stage dut (
        .clk(clk), .rst(rst), .decoded_valid_i(decoded_valid),
        .decoded_uop_i(decoded), .decoded_ready_o(decoded_ready),
        .map_source_1_arch_o(map_rs1), .map_source_2_arch_o(map_rs2),
        .map_destination_arch_o(map_rd), .map_source_1_phys_i(rs1_phys),
        .map_source_2_phys_i(rs2_phys),
        .map_stale_destination_phys_i(stale_phys),
        .prf_source_1_value_i(rs1_value), .prf_source_2_value_i(rs2_value),
        .prf_source_1_ready_i(rs1_ready), .prf_source_2_ready_i(rs2_ready),
        .free_allocate_valid_i(free_valid), .free_allocate_phys_i(free_phys),
        .free_allocate_ready_o(free_ready), .rob_dispatch_tag_i(rob_tag),
        .dispatch_ready_i(dispatch_ready), .dispatch_valid_o(dispatch_valid),
        .dispatch_packet_o(packet), .map_rename_valid_o(map_rename_valid),
        .map_rename_arch_o(map_rename_arch),
        .map_rename_phys_o(map_rename_phys),
        .prf_allocate_valid_o(prf_allocate_valid),
        .prf_allocate_phys_o(prf_allocate_phys),
        .checkpoint_save_valid_o(checkpoint_valid),
        .checkpoint_branch_tag_o(checkpoint_tag));

    initial clk = 0;
    always #5 clk = ~clk;
    task automatic check(input logic condition, input string name);
        if (!condition) begin $error("%s", name); errors++; end
    endtask

    initial begin
        errors=0; rst=0; decoded_valid=1; decoded=DECODED_UOP_EMPTY;
        decoded.valid=1; decoded.uses_rs1=1; decoded.uses_rs2=1;
        decoded.writes_rd=1; decoded.rs1_arch=2; decoded.rs2_arch=3;
        decoded.rd_arch=5; decoded.control_flow=CONTROL_FLOW_BRANCH;
        rs1_phys=34; rs2_phys=35; stale_phys=5;
        rs1_value=11; rs2_value=12; rs1_ready=1; rs2_ready=0;
        free_valid=1; free_phys=40; rob_tag='0; rob_tag.position=3;
        dispatch_ready=0; #1;
        check(dispatch_valid && !decoded_ready, "valid held under backpressure");
        check(!free_ready && !map_rename_valid && !prf_allocate_valid,
              "no state update before atomic acceptance");
        check(packet.uop.rd_phys==40 && packet.uop.stale_rd_phys==5,
              "renamed destination payload");
        check(packet.source_2.tag==35 && !packet.source_2.ready,
              "waiting source payload");

        dispatch_ready=1; #1;
        check(decoded_ready && free_ready && map_rename_valid &&
              prf_allocate_valid && checkpoint_valid,
              "atomic dispatch side effects");

        decoded.writes_rd=0; decoded.rd_arch=0; free_valid=0;
        decoded.control_flow=CONTROL_FLOW_NONE; #1;
        check(decoded_ready && dispatch_valid && !free_ready &&
              !map_rename_valid, "no-destination dispatch without free tag");

        decoded.writes_rd=1; decoded.rd_arch=6; #1;
        check(!dispatch_valid && !decoded_ready,
              "destination waits for free register");

        if(errors==0) $display("PASS: rename_stage_tb");
        else $fatal(1,"FAIL: rename_stage_tb had %0d errors",errors);
        $finish;
    end
endmodule
