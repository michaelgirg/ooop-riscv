import rv32i_pkg::*;

// ID/EX pipeline register.

//This register seprates the Instruction Decode (ID) stage
//from the Exectuion (EX) stage.



//At every rising clk edge it does 4 things: 

/*
1. Reset: clears the reg to a bubble 
2. Flush: removes the current instruction by inserting a bubble 
3. Enable. advances the decoded instruction into the EX stage
4. Otherwise: hold its current contents during a pipeline stall
*/

/*
A bubble inserts an empty cucle in front of a waiting instruction like 
allowing the earlier instruction enough time to finish 

In this case we have lw and we are waiting for x5 since we can't add x5 and x6 since 
lw hasn't finished.

lw  x5 0(x1)
add x6, x5, x2

The flow would look like this lw -> bubble -> add

THIS IS THE REASON FOR A OOOP
*/

module id_ex_reg (
    input logic clk,
    input logic rst,
    input logic en,
    input logic flush,
    
    input id_ex_t data, //Info produced from the Decode Stage
    output id_ex_t data_o //registerd info sent into the execute stage 
);

    always_ff @(posedge clk) begin
        if (rst || flush) data_o <= ID_EX_BUBBLE; //rst or flush rmvs the current instruction by inserting a bubble
        else if (en) data_o <= data; //advance the decoded instruction when the pipeline is enables
        //Otherwise data_o holds its current value during a stall 
    end


endmodule

