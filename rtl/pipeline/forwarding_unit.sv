import rv32i_pkg::*;

// Data forwarding unit.

// Forwarding allows us to avoid those unnecesary stalls by taking a recently calculated value
// directly from a later pipeline stage instead of waiting for it to be written into the reg file

// Slection Value:
// 2'b00: use the original value read from the reg file 
// 2'b01: forward the value from the MEM/WB stage
// 2'b10: forward the value from the EX/MEM stage 

// EX/MEM gets prio since it contains the newer instruction. 

module forwarding_unit (

    // Src regs used by instructions currently in Execute 
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,

    // Instructions currrently in later pipeline stages
    input ex_mem_t ex_mem_data,
    input mem_wb_t mem_wb_data,

    // Select signals for the forwarding muxs
    output logic [1:0] forward_a,
    output logic [1:0] forward_b,
);

    always_comb begin
        // Deafult: Use the values originally read from the reg file 
        forward_a = 2'b00;
        forward_b = 2'b00;

        // Check MEM/WB first. EX/MEM is checked afterward so it can override
        // this selection when both stages write the same register
        // Note: the third condition means dont fwd if the destination reg is x0 since thats always 0
        if (mem_wb_data.valid && mem_wb_data.reg_write && (mem_wb_data.rd_addr != 5'd0)) begin
            // These statments are saying if the instruction in MEM/WB is writing the same reg
            // that the current insutrction needs like rs1, then tell the ALU input A mux to use the MEM/WB 
            // value so we use this new value instead of the old 
            if (mem_wb_data.rd_addr == rs1_addr) forward_a = 2'b01;
            if (mem_wb_data.rd_addr == rs2_addr) forward_b = 2'b01;
        end

        // Forward from EX/MEM when it contains the newest required result

        // A load cannot forward from EX/MEM because alu_result is only its mem addr
        // The loaded value becomes avilable in MEM/WB
        if (ex_mem_data.valid && ex_mem_data.reg_write && !ex_mem_data.mem_read && (ex_mem_data.rd_addr != 5'd0)) begin
            if (ex_mem_data.rd_addr == rs1_addr) forward_a = 2'b10; 
            if (ex_mem_data.rd_addr == rs2_addr) forward_b = 2'b10;
        end
    end

endmodule 