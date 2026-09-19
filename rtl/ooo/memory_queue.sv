import ooo_pkg::*;
import rv32i_pkg::*;

// Conservative load/store queue for the first OOO core.
//
// Owner: Together
// Depends on: ROB head/age, result arbiter, recovery, and commit unit
//
// This first version may calculate memory addresses out of order, but a load
// accesses the D-cache only when it reaches the ROB head. A store accesses the
// D-cache only after commit_unit explicitly authorizes that ROB tag. This is
// intentionally conservative and gives precise, exactly-once stores before a
// speculative load/store queue is attempted.

module memory_queue (
    input logic clk,
    input logic rst,

    input  logic                 dispatch_valid_i,
    input  var dispatch_packet_t dispatch_packet_i,
    output logic                 dispatch_ready_o,

    input var result_bus_t result_i,

    input var rob_tag_t        rob_head_tag_i,
    input var recovery_event_t recovery_i,
    input logic                flush_all_i,

    // Load completion or store-address completion to the result arbiter.
    output logic            result_valid_o,
    output var completion_t result_o,
    input  logic            result_ready_i,

    // Store authorization from the in-order commit unit.
    input  logic     store_commit_valid_i,
    input  var rob_tag_t store_commit_tag_i,
    output logic     store_commit_done_o,
    output logic     store_commit_fault_o,

    // Existing D-cache CPU-side interface.
    output logic        dcache_req_valid_o,
    output logic        dcache_req_write_o,
    output logic [31:0] dcache_req_addr_o,
    output logic [31:0] dcache_req_wdata_o,
    output logic [2:0]  dcache_req_funct3_o,
    input  logic        dcache_req_ready_i,

    output logic        dcache_resp_ready_o,
    input  logic        dcache_resp_valid_i,
    input  logic [31:0] dcache_resp_rdata_i,
    input  logic        dcache_resp_hit_i,
    input  logic        dcache_resp_miss_i,
    input  logic        dcache_resp_fault_i,

    output logic full_o,
    output logic empty_o
);

    dispatch_packet_t entries_q [0:MEMORY_QUEUE_ENTRIES-1];
    logic valid_q [0:MEMORY_QUEUE_ENTRIES-1];
    logic address_ready_q [0:MEMORY_QUEUE_ENTRIES-1];
    logic [31:0] address_q [0:MEMORY_QUEUE_ENTRIES-1];
    logic [31:0] store_data_q [0:MEMORY_QUEUE_ENTRIES-1];
    logic address_reported_q [0:MEMORY_QUEUE_ENTRIES-1];

    completion_t result_q;
    logic outstanding_q;
    logic outstanding_write_q;
    logic outstanding_squashed_q;
    memory_queue_index_t outstanding_index_q;
    rob_tag_t outstanding_tag_q;

    logic request_valid;
    logic request_write;
    memory_queue_index_t request_index;
    logic store_report_valid;
    memory_queue_index_t store_report_index;
    logic issue_result_slot;
    logic response_fire;

    function automatic logic address_misaligned(
        input logic [31:0] address,
        input mem_size_t access_size
    );
        case (access_size)
            MEM_HALF: return address[0];
            MEM_WORD: return |address[1:0];
            default: return 1'b0;
        endcase
    endfunction

    always_comb begin
        empty_o = 1'b1;
        full_o = 1'b1;
        for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
            if (valid_q[index]) empty_o = 1'b0;
            if (!valid_q[index]) full_o = 1'b0;
        end
        dispatch_ready_o = !full_o && !recovery_i.valid && !flush_all_i;

        result_valid_o = result_q.valid;
        result_o = result_q;
        issue_result_slot = !result_q.valid || result_ready_i;

        // Find an address completion to report. Stores report their address
        // before commit; misaligned loads report an exception without issuing.
        store_report_valid = 1'b0;
        store_report_index = '0;
        for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
            if (valid_q[index] && address_ready_q[index] &&
                !address_reported_q[index] &&
                ((entries_q[index].uop.decoded.uop_class == UOP_STORE) ||
                 address_misaligned(address_q[index],
                                    entries_q[index].uop.decoded.mem_size))) begin
                if (!store_report_valid ||
                    rob_is_younger(
                        entries_q[store_report_index].uop.rob_tag,
                        entries_q[index].uop.rob_tag, rob_head_tag_i)) begin
                    store_report_valid = 1'b1;
                    store_report_index = memory_queue_index_t'(index);
                end
            end
        end

        // A committed store has priority over a head load. Both payloads stay
        // stable because their queue entries cannot be removed before request
        // acceptance.
        request_valid = 1'b0;
        request_write = 1'b0;
        request_index = '0;
        if (!outstanding_q && !flush_all_i && !recovery_i.valid) begin
            for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
                if (!request_valid && valid_q[index] &&
                    (entries_q[index].uop.decoded.uop_class == UOP_STORE) &&
                    address_ready_q[index] && address_reported_q[index] &&
                    store_commit_valid_i &&
                    (entries_q[index].uop.rob_tag == store_commit_tag_i)) begin
                    request_valid = 1'b1;
                    request_write = 1'b1;
                    request_index = memory_queue_index_t'(index);
                end
            end

            if (!request_valid) begin
                for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
                    if (!request_valid && valid_q[index] &&
                        (entries_q[index].uop.decoded.uop_class == UOP_LOAD) &&
                        address_ready_q[index] &&
                        !address_misaligned(
                            address_q[index],
                            entries_q[index].uop.decoded.mem_size) &&
                        (entries_q[index].uop.rob_tag == rob_head_tag_i)) begin
                        request_valid = 1'b1;
                        request_write = 1'b0;
                        request_index = memory_queue_index_t'(index);
                    end
                end
            end
        end

        dcache_req_valid_o = request_valid;
        dcache_req_write_o = request_write;
        dcache_req_addr_o = request_valid ? address_q[request_index] : '0;
        dcache_req_wdata_o = request_valid ? store_data_q[request_index] : '0;
        dcache_req_funct3_o = request_valid
            ? {(!request_write &&
                entries_q[request_index].uop.decoded.load_unsigned),
               entries_q[request_index].uop.decoded.mem_size}
            : 3'b010;

        // A load response needs room on the common-result producer. A store
        // response is consumed directly by the in-order commit handshake.
        dcache_resp_ready_o = outstanding_q &&
            (outstanding_write_q || outstanding_squashed_q ||
             issue_result_slot);
        response_fire = dcache_resp_valid_i && dcache_resp_ready_o;

        store_commit_done_o = response_fire && outstanding_write_q &&
                              !outstanding_squashed_q &&
                              !dcache_resp_fault_i &&
                              store_commit_valid_i &&
                              (store_commit_tag_i == outstanding_tag_q);
        store_commit_fault_o = response_fire && outstanding_write_q &&
                               !outstanding_squashed_q &&
                               dcache_resp_fault_i &&
                               store_commit_valid_i &&
                               (store_commit_tag_i == outstanding_tag_q);
    end

    always_ff @(posedge clk) begin : memory_queue_state
        logic inserted;
        dispatch_packet_t incoming;
        completion_t completion;
        logic result_response_this_cycle;

        if (rst) begin
            for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
                valid_q[index] <= 1'b0;
                entries_q[index] <= DISPATCH_PACKET_EMPTY;
                address_ready_q[index] <= 1'b0;
                address_q[index] <= '0;
                store_data_q[index] <= '0;
                address_reported_q[index] <= 1'b0;
            end
            result_q <= COMPLETION_EMPTY;
            outstanding_q <= 1'b0;
            outstanding_write_q <= 1'b0;
            outstanding_squashed_q <= 1'b0;
            outstanding_index_q <= '0;
            outstanding_tag_q <= '0;
        end else begin
            result_response_this_cycle = response_fire &&
                                         !outstanding_write_q &&
                                         !outstanding_squashed_q;

            if (result_q.valid && result_ready_i)
                result_q <= COMPLETION_EMPTY;

            if (result_i.valid && result_i.writes_phys) begin
                for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
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

            // Calculate addresses as soon as both required operands are ready.
            for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
                if (valid_q[index] && !address_ready_q[index] &&
                    entries_q[index].source_1.ready &&
                    entries_q[index].source_2.ready) begin
                    address_q[index] <= entries_q[index].source_1.value +
                                        entries_q[index].uop.decoded.immediate;
                    store_data_q[index] <= entries_q[index].source_2.value;
                    address_ready_q[index] <= 1'b1;
                end
            end

            if (dcache_req_valid_o && dcache_req_ready_i) begin
                outstanding_q <= 1'b1;
                outstanding_write_q <= request_write;
                outstanding_squashed_q <= 1'b0;
                outstanding_index_q <= request_index;
                outstanding_tag_q <= entries_q[request_index].uop.rob_tag;
            end

            if (response_fire) begin
                outstanding_q <= 1'b0;
                if (!outstanding_squashed_q) begin
                    if (outstanding_write_q) begin
                        valid_q[outstanding_index_q] <= 1'b0;
                    end else begin
                        completion = COMPLETION_EMPTY;
                        completion.valid = 1'b1;
                        completion.rob_tag = outstanding_tag_q;
                        completion.writes_phys =
                            entries_q[outstanding_index_q].uop.has_phys_destination;
                        completion.rd_phys =
                            entries_q[outstanding_index_q].uop.rd_phys;
                        completion.result = dcache_resp_rdata_i;
                        if (dcache_resp_fault_i) begin
                            completion.writes_phys = 1'b0;
                            completion.exception_valid = 1'b1;
                            completion.exception_cause = EXC_LOAD_ACCESS_FAULT;
                            completion.exception_value =
                                address_q[outstanding_index_q];
                        end
                        result_q <= completion;
                        valid_q[outstanding_index_q] <= 1'b0;
                    end
                end
            end

            // Report store addresses and all misalignment exceptions without
            // using the D-cache. A returning load response has priority.
            if (store_report_valid && issue_result_slot &&
                !result_response_this_cycle && !flush_all_i &&
                !recovery_i.valid) begin
                completion = COMPLETION_EMPTY;
                completion.valid = 1'b1;
                completion.rob_tag =
                    entries_q[store_report_index].uop.rob_tag;
                completion.memory_address_valid = 1'b1;
                completion.memory_address = address_q[store_report_index];
                completion.store_data = store_data_q[store_report_index];

                if (address_misaligned(
                    address_q[store_report_index],
                    entries_q[store_report_index].uop.decoded.mem_size)) begin
                    completion.exception_valid = 1'b1;
                    completion.exception_value = address_q[store_report_index];
                    if (entries_q[store_report_index].uop.decoded.uop_class ==
                        UOP_STORE) begin
                        completion.exception_cause =
                            EXC_STORE_ADDRESS_MISALIGNED;
                    end else begin
                        completion.exception_cause =
                            EXC_LOAD_ADDRESS_MISALIGNED;
                    end
                    valid_q[store_report_index] <= 1'b0;
                end

                address_reported_q[store_report_index] <= 1'b1;
                result_q <= completion;
            end

            if (flush_all_i) begin
                for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++)
                    valid_q[index] <= 1'b0;
                result_q <= COMPLETION_EMPTY;
                if (outstanding_q)
                    outstanding_squashed_q <= 1'b1;
            end else if (recovery_i.valid) begin
                for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
                    if (valid_q[index] &&
                        rob_is_younger(entries_q[index].uop.rob_tag,
                                       recovery_i.branch_tag,
                                       rob_head_tag_i)) begin
                        valid_q[index] <= 1'b0;
                    end
                end
                if (result_q.valid &&
                    rob_is_younger(result_q.rob_tag, recovery_i.branch_tag,
                                   rob_head_tag_i)) begin
                    result_q <= COMPLETION_EMPTY;
                end
                if (outstanding_q &&
                    rob_is_younger(outstanding_tag_q,
                                   recovery_i.branch_tag, rob_head_tag_i)) begin
                    outstanding_squashed_q <= 1'b1;
                end
            end else if (dispatch_valid_i && dispatch_ready_o) begin
                incoming = dispatch_packet_i;
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
                for (int index = 0; index < MEMORY_QUEUE_ENTRIES; index++) begin
                    if (!valid_q[index] && !inserted) begin
                        entries_q[index] <= incoming;
                        valid_q[index] <= 1'b1;
                        address_ready_q[index] <=
                            incoming.source_1.ready &&
                            incoming.source_2.ready;
                        address_q[index] <= incoming.source_1.value +
                                            incoming.uop.decoded.immediate;
                        store_data_q[index] <= incoming.source_2.value;
                        address_reported_q[index] <= 1'b0;
                        inserted = 1'b1;
                    end
                end
            end
        end
    end

endmodule
