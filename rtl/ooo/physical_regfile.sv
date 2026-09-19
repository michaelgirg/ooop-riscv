import ooo_pkg::*;

// Physical register file for the single-wide OOO core.
//
// Independent first task: yes
//
// Expected behavior:
// - Reset gives every register a known zero value. p0 through p31 are ready
//   because the reset rename map initially points architectural registers at
//   those physical registers; p32 through p63 begin free and not ready.
// - Allocating a destination marks that physical register not ready.
// - Accepting a matching result writes its value and marks it ready.
// - p0 ignores allocation and writeback and always reads as ready zero.
// - Squashed values do not need to be erased. The free list returns their
//   tags, and the next allocation clears readiness before reuse.

module physical_regfile (
    input logic clk,
    input logic rst,

    // These are the physical-register numbers
    input  phys_reg_t   source_1_tag_i,
    input  phys_reg_t   source_2_tag_i,

    // The actual value stored in the physical reg
    output logic [31:0] source_1_value_o,
    output logic [31:0] source_2_value_o,

    // Tells reservation station or issue logic wether the values have been calculated
    // Reservation station is to hold instructions until all their input operands are ready
    // Issue logic chooses which instruction is ready
    output logic        source_1_ready_o,
    output logic        source_2_ready_o,

    // One destination is allocated because rename is single-wide.
    input phys_reg_t allocate_tag_i, //true when rename is assigning a physical reg
    input logic      allocate_valid_i,

    // The common result bus is the only normal writeback source.
    input var result_bus_t result_i
);

    logic [OOO_XLEN-1:0] value_q [0:PHYS_REG_COUNT-1]; // array containing the values of all physical registers
    logic                ready_q [0:PHYS_REG_COUNT-1]; // 1 ready bit for every physical register

    // Reads are asynchronous so rename/issue can inspect both operands in the
    // current cycle. p0 is forced here as well as in the sequential logic.
    always_comb begin
        source_1_value_o = (source_1_tag_i == PHYS_ZERO) ? '0 : value_q[source_1_tag_i];
        source_2_value_o = (source_2_tag_i == PHYS_ZERO) ? '0 : value_q[source_2_tag_i];
        source_1_ready_o = (source_1_tag_i == PHYS_ZERO) ? 1'b1 : ready_q[source_1_tag_i];
        source_2_ready_o = (source_2_tag_i == PHYS_ZERO) ? 1'b1 : ready_q[source_2_tag_i];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int tag = 0; tag < PHYS_REG_COUNT; tag++) begin
                value_q[tag] <= '0;
                ready_q[tag] <= (tag < ARCH_REG_COUNT);
            end
        end else begin
            // Writeback updates both the value and readiness. A result that
            // does not write a physical destination has no PRF side effect.
            if (result_i.valid && result_i.writes_phys && // real result & has physical destination
                (result_i.rd_phys != PHYS_ZERO) && // destination cant be p0
                // there are times when a old instruction and new instruction have the same dest reg and once the new insutrction starts
                // the result of the old instruction shows up and when that happens u dont write back (note allocate_valid_i is true only
                // during the first cycle of the start of the new instruction and thats when the old instructions results comes in)
                !(allocate_valid_i && (allocate_tag_i == result_i.rd_phys))) begin //
                value_q[result_i.rd_phys] <= result_i.result; // store the calculated result in the destination reg
                ready_q[result_i.rd_phys] <= 1'b1;
            end

            // A newly reused tag must remain not ready even if a stale result
            // for that tag arrives in the allocation cycle.
            if (allocate_valid_i && (allocate_tag_i != PHYS_ZERO))
                ready_q[allocate_tag_i] <= 1'b0;
            // perma enforce p0
            value_q[PHYS_ZERO] <= '0;
            ready_q[PHYS_ZERO] <= 1'b1;
        end
    end

endmodule
