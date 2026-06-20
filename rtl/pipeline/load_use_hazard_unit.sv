import rv32i_pkg::*;

// Load-use hazard detector.
// 
// This module detects the classic load use hazard 

// lw  x5, 0(x1)
// add x6, x5, x2

/*
The load is in the EX stage, but the instruction is in Decode already and needs
the loaded value. Since the load data is not avaliable until the MEM/WB stage forwarding
cannot fix this immediately

So we stall the front of the pipeline for one cycle and insert a bubble into ID/EX 
lw -> bubbble -> add

Important Notes:
We cannot just take lw from the EX/MEM stage as that is just the memory address that the ALU
just calculated the actual memeory data we are looking for comes during that MEM stage. That is 
why we wait for the MEM/WB stage. 

When we add that bubble it allows for our lw to finsih the EX and when its in the MEM/WB stage 
the forwarding unit can now finally take that data that we want for the add and put it in 
for ID and we can finally execute that add.
This is why OOO is nice so we can actually do an indepedent instruction instead of doing a bubble. 


RAW = Read after Write hazard where the newer instruction wants to read from a register before the older instruction has 
actually finished writing it 
*/

module load_hazard_unit (

    // Instruction currently sitting in Decode
    input logic if_id_valid,
    input logic [4:0] if_id_rs1_addr,
    input logic [4:0] if_id_rs2_addr,

    // Instruction currently sitting in EX
    input id_ex_t id_ex_data,

    // Control outputs used by the top level pipeline
    output logic stall_pc,
    output logic stall_if_id, // keeps the current decode instruction in IF/ID and doesnt let it move forward
    output logic flush_id_ex // flushing creates the bubble/NOP 
);

    logic uses_rs1;
    logic uses_rs2;
    logic hazard;

    always_comb begin
        // Deafult: no hazard, pipeline moves normally
        stall_pc = '0
        stall_if_id = '0;
        flush_id_ex = '0;

        // rs1 is used when it is not x0 and matches the load destination 
        uses_rs1 = (if_id_rs1_addr != 5'd0) &&
                   (if_id_rs1_addr == id_ex_data.rd_addr);

        // rs2 is also checked because stores, branches, and R-type 
        // instructionsa may need rs2 
        uses_rs2 = (if_id_rs2_addr != 5'd0) &&
                   (if_id_rs2_addr == id_ex_data.rd_addr);
        
        /*
        A load use hazard exists when:
            - Decode has a real instruction.
            - Execute has a real instruction.
            - Execute instruction is a load.
            - The load writes a nonzero destination register.
            - Decode needs that destination register as rs1 or rs2.
        */
        hazard = if_id_valid &&
                 id_ex_data.valid &&
                 id_ex_data.mem_read &&
                 id_ex_data.reg_write &&
                 (id_ex_data.rd_addr != 5'd0) &&
                 (uses_rs1 || uses_rs2);
        if (hazard) begin
            stall_pc = 1'b1 // Keeps our PC from fetching a new instruction
            stall_if_id = 1'b1; // Keep the waiting instruction in the IF/ID
            flush_id_ex = 1'b1; // Insert a bubble into the ID/EX stage so the load can get to the MEM/WB
        end          
    end

endmodule
