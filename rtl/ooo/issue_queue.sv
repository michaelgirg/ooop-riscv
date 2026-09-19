import ooo_pkg::*;

// Integer, branch, jump, and MUL/DIV issue queue.
//
// Owner: Ant
// Depends on: result-bus contract and ROB recovery/age contract
//
// Each source begins ready with a value or waiting on a physical tag. An
// accepted result bus broadcast wakes every matching source. Selection chooses
// the oldest ready instruction that its execution unit can currently accept.

module issue_queue (
    input logic clk,
    input logic rst,

    input  logic                 dispatch_valid_i,
    input  var dispatch_packet_t dispatch_packet_i,
    output logic                 dispatch_ready_o,

    input var result_bus_t result_i,

    input var rob_tag_t        rob_head_tag_i,
    input var recovery_event_t recovery_i,
    input logic flush_all_i,

    output logic                   issue_valid_o,
    output var execution_request_t issue_request_o,
    input  logic                   issue_ready_i,

    output logic full_o,
    output logic empty_o
);

    dispatch_packet_t entries_q [0:ISSUE_QUEUE_ENTRIES-1];
    logic valid_q [0:ISSUE_QUEUE_ENTRIES-1];

    logic candidate_valid;
    issue_queue_index_t candidate_index;
    logic issue_fire;

    always_comb begin
        candidate_valid = 1'b0;
        candidate_index = '0;

        for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
            if (valid_q[index] && entries_q[index].source_1.ready &&
                entries_q[index].source_2.ready) begin
                if (!candidate_valid ||
                    rob_is_younger(entries_q[candidate_index].uop.rob_tag,
                                   entries_q[index].uop.rob_tag,
                                   rob_head_tag_i)) begin
                    candidate_valid = 1'b1;
                    candidate_index = issue_queue_index_t'(index);
                end
            end
        end

        issue_request_o = EXECUTION_REQUEST_EMPTY;
        if (candidate_valid) begin
            issue_request_o.uop = entries_q[candidate_index].uop;
            issue_request_o.source_1_value =
                entries_q[candidate_index].source_1.value;
            issue_request_o.source_2_value =
                entries_q[candidate_index].source_2.value;
        end

        issue_valid_o = candidate_valid && !recovery_i.valid && !flush_all_i;

        empty_o = 1'b1;
        full_o = 1'b1;
        for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
            if (valid_q[index]) empty_o = 1'b0;
            if (!valid_q[index]) full_o = 1'b0;
        end
        dispatch_ready_o = !full_o && !recovery_i.valid && !flush_all_i;
    end

    // Keep the ready/valid transfer detector out of the selection block. This
    // avoids creating a zero-time feedback path through an execution unit
    // whose ready signal depends on the selected operation type.
    assign issue_fire = issue_valid_o && issue_ready_i;

    always_ff @(posedge clk) begin : issue_queue_state
        logic inserted;
        dispatch_packet_t incoming;

        if (rst) begin
            for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
                valid_q[index] <= 1'b0;
                entries_q[index] <= DISPATCH_PACKET_EMPTY;
            end
        end else if (flush_all_i) begin
            for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
                valid_q[index] <= 1'b0;
                entries_q[index] <= DISPATCH_PACKET_EMPTY;
            end
        end else begin
            // Broadcast wakeup updates every matching source in parallel.
            if (result_i.valid && result_i.writes_phys) begin
                for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
                    if (valid_q[index] && entries_q[index].source_1.used &&
                        !entries_q[index].source_1.ready &&
                        (entries_q[index].source_1.tag == result_i.rd_phys)) begin
                        entries_q[index].source_1.ready <= 1'b1;
                        entries_q[index].source_1.value <= result_i.result;
                    end
                    if (valid_q[index] && entries_q[index].source_2.used &&
                        !entries_q[index].source_2.ready &&
                        (entries_q[index].source_2.tag == result_i.rd_phys)) begin
                        entries_q[index].source_2.ready <= 1'b1;
                        entries_q[index].source_2.value <= result_i.result;
                    end
                end
            end

            if (issue_fire)
                valid_q[candidate_index] <= 1'b0;

            if (recovery_i.valid) begin
                for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
                    if (valid_q[index] &&
                        rob_is_younger(entries_q[index].uop.rob_tag,
                                       recovery_i.branch_tag,
                                       rob_head_tag_i)) begin
                        valid_q[index] <= 1'b0;
                    end
                end
            end else if (dispatch_valid_i && dispatch_ready_o) begin
                incoming = dispatch_packet_i;
                // A completion accepted in the dispatch cycle must also wake
                // the new entry because the PRF write occurs on this edge.
                if (result_i.valid && result_i.writes_phys) begin
                    if (incoming.source_1.used &&
                        !incoming.source_1.ready &&
                        (incoming.source_1.tag == result_i.rd_phys)) begin
                        incoming.source_1.ready = 1'b1;
                        incoming.source_1.value = result_i.result;
                    end
                    if (incoming.source_2.used &&
                        !incoming.source_2.ready &&
                        (incoming.source_2.tag == result_i.rd_phys)) begin
                        incoming.source_2.ready = 1'b1;
                        incoming.source_2.value = result_i.result;
                    end
                end

                inserted = 1'b0;
                for (int index = 0; index < ISSUE_QUEUE_ENTRIES; index++) begin
                    if (!valid_q[index] && !inserted) begin
                        entries_q[index] <= incoming;
                        valid_q[index] <= 1'b1;
                        inserted = 1'b1;
                    end
                end
            end
        end
    end

endmodule
