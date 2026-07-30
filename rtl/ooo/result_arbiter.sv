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

    // TODO(Ant): Add fair arbitration, output valid/payload selection, and
    // ready routing. Keep the selected payload stable during back-pressure.

endmodule
