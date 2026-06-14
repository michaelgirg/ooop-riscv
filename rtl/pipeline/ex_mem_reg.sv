import rv32i_pkg::*;

// EX/MEM pipeline register.


//This reg seprates the Execute (EX) stage from the Memory (MEM) stage

/*Stores info calculated during EX: 
-- The ALU result
-- Store data 
-- Destination Reg
-- Mem Ctrl Signal 
-- Reg WB controls

At each rising clk edge: 
-- Rst or Flush inserts a bubble 
-- Enable advances the instruction into the Memory stage
-- Otherwise, the current contents are held during a stall
*/


module ex_mem_reg (
    input logic clk,
    input logic rst,
    input logic en, 
    input logic flush, 
    input ex_mem_t data, //results and ctrl signals from the EX stage

    output ex_mem_t data_o //registered info sent into the Mem stage
);

    always_ff @(posedge clk) begin
        //rst and flush both remove the curr instruction by replacing it with a bubble
        //A bubble has a valid = 0 and cannot change mem or th reg file
        if (rst || flush) data_o <= EX_MEM_BUBBLE;
        else if (en) data_o <= data; //when enabled we advance the EX results into the MEM stage
        //When en = 0 we keep the current contents until the pipeline can advance
    end


endmodule 