import ooo_pkg::*;

// Single common result-bus arbiter.
//
// Owner: Ant
// Independent first task: yes
//
// Version one merges execution and memory completion producers onto one bus.
// A producer remains back-pressured until its exact payload is accepted. Use a
// fair policy so repeated ALU completions cannot starve a returning load.

module result_arbiter (
    input logic clk,
    input logic rst,

    input  logic            execute_valid_i,
    input  var completion_t execute_result_i,
    output logic            execute_ready_o,

    input  logic            memory_valid_i,
    input  var completion_t memory_result_i,
    output logic            memory_ready_o,

    output var result_bus_t result_o,
    input  logic            result_ready_i
);

    // 0 prefers execute on the next collision; 1 prefers memory.
    logic prefer_memory_q;
    logic select_memory;
    logic transfer;

    always_comb begin
        execute_ready_o = 1'b0;
        memory_ready_o = 1'b0;
        result_o = COMPLETION_EMPTY;
        select_memory = 1'b0;

        if (execute_valid_i && memory_valid_i)
            select_memory = prefer_memory_q;
        else if (memory_valid_i)
            select_memory = 1'b1;

        if (select_memory && memory_valid_i) begin
            result_o = memory_result_i;
            result_o.valid = 1'b1;
            memory_ready_o = result_ready_i;
        end else if (execute_valid_i) begin
            result_o = execute_result_i;
            result_o.valid = 1'b1;
            execute_ready_o = result_ready_i;
        end

        transfer = result_o.valid && result_ready_i;
    end

    always_ff @(posedge clk) begin
        if (rst)
            prefer_memory_q <= 1'b0;
        else if (transfer)
            prefer_memory_q <= !select_memory;
    end

endmodule
