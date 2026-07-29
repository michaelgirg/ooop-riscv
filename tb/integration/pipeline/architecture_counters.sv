`timescale 1ns/1ps

// Architecture-independent simulation counters.
//
// The pipeline and future OOO core can drive the same event inputs, which
// makes cycle, stall, branch, and cache behavior directly comparable. This is
// intentionally verification-only so measurement logic cannot disturb the
// timing-closed processor implementation.
module architecture_counters (
    input logic clk,
    input logic rst,
    input logic active,

    input logic retire_event,
    input logic stall_event,
    input logic branch_event,
    input logic redirect_event,
    input logic icache_hit_event,
    input logic icache_miss_event,
    input logic dcache_hit_event,
    input logic dcache_miss_event,
    input logic store_event,
    input logic muldiv_issue_event,

    output logic [63:0] cycle_count,
    output logic [63:0] retire_count,
    output logic [63:0] stall_cycle_count,
    output logic [63:0] branch_count,
    output logic [63:0] redirect_count,
    output logic [63:0] icache_hit_count,
    output logic [63:0] icache_miss_count,
    output logic [63:0] dcache_hit_count,
    output logic [63:0] dcache_miss_count,
    output logic [63:0] store_count,
    output logic [63:0] muldiv_issue_count
);

    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_count        <= '0;
            retire_count       <= '0;
            stall_cycle_count  <= '0;
            branch_count       <= '0;
            redirect_count     <= '0;
            icache_hit_count   <= '0;
            icache_miss_count  <= '0;
            dcache_hit_count   <= '0;
            dcache_miss_count  <= '0;
            store_count        <= '0;
            muldiv_issue_count <= '0;
        end
        else begin
            if (active) cycle_count <= cycle_count + 64'd1;

            if (retire_event)       retire_count <= retire_count + 64'd1;
            if (active && stall_event)
                stall_cycle_count <= stall_cycle_count + 64'd1;
            if (branch_event)       branch_count <= branch_count + 64'd1;
            if (redirect_event)     redirect_count <= redirect_count + 64'd1;
            if (icache_hit_event)   icache_hit_count <= icache_hit_count + 64'd1;
            if (icache_miss_event)  icache_miss_count <= icache_miss_count + 64'd1;
            if (dcache_hit_event)   dcache_hit_count <= dcache_hit_count + 64'd1;
            if (dcache_miss_event)  dcache_miss_count <= dcache_miss_count + 64'd1;
            if (store_event)        store_count <= store_count + 64'd1;
            if (muldiv_issue_event)
                muldiv_issue_count <= muldiv_issue_count + 64'd1;
        end
    end

endmodule
