// slow_line_memory.sv -- delayed cache-line backing memory
//
// This module gives the caches a realistic variable-latency boundary instead
// of answering every access combinationally. One request can be outstanding at
// a time. Reads return a complete cache line through a valid/ready response;
// writes update a complete line and finish without a response, matching the
// current I-cache and D-cache memory-side contracts.

module slow_line_memory #(
    parameter int ADDR_WIDTH  = 32,
    parameter int DATA_WIDTH  = 32,
    parameter int LINE_WORDS  = 4,
    parameter int DEPTH_WORDS = 1024,
    parameter int LATENCY     = 15,
    parameter string HEX_FILE = ""
) (
    input logic clk,
    input logic rst,

    input  logic                               req_valid,
    output logic                               req_ready,
    input  logic                               req_write,
    input  logic [ADDR_WIDTH-1:0]              req_addr,
    input  logic [(DATA_WIDTH*LINE_WORDS)-1:0] req_wdata,

    output logic                               resp_valid,
    input  logic                               resp_ready,
    output logic [(DATA_WIDTH*LINE_WORDS)-1:0] resp_rdata,
    output logic                               resp_fault
);

    localparam int BYTES_PER_WORD   = DATA_WIDTH / 8;
    localparam int LINE_BYTES       = LINE_WORDS * BYTES_PER_WORD;
    localparam int LINE_BITS        = DATA_WIDTH * LINE_WORDS;
    localparam int BYTE_OFFSET_BITS = $clog2(BYTES_PER_WORD);
    localparam int LINE_OFFSET_BITS = $clog2(LINE_BYTES);
    localparam int COUNT_BITS       = (LATENCY <= 1) ? 1 : $clog2(LATENCY + 1);

    typedef enum logic [1:0] {
        MEMORY_IDLE,
        MEMORY_WAIT,
        MEMORY_RESPONSE
    } memory_state_t;

    memory_state_t state;

    // Word storage keeps the existing .hex files and testbench inspection
    // readable while the cache-facing interface still transfers full lines.
    logic [DATA_WIDTH-1:0] mem [0:DEPTH_WORDS-1];

    logic                  pending_write;
    logic [ADDR_WIDTH-1:0] pending_addr;
    logic [LINE_BITS-1:0]  pending_wdata;
    logic                  pending_fault;
    logic [COUNT_BITS-1:0] cycles_left;

    logic [LINE_BITS-1:0] pending_read_line;
    int unsigned pending_base_word;

    assign req_ready = (state == MEMORY_IDLE);

    function automatic logic request_fault(
        input logic [ADDR_WIDTH-1:0] address
    );
        longint unsigned base_word;

        begin
            base_word = $unsigned(address) >> BYTE_OFFSET_BITS;
            request_fault =
                (address[LINE_OFFSET_BITS-1:0] != '0) ||
                (base_word > (DEPTH_WORDS - LINE_WORDS));
        end
    endfunction

    always_comb begin
        pending_read_line = '0;
        pending_base_word = int'($unsigned(pending_addr) >> BYTE_OFFSET_BITS);

        if (!pending_fault) begin
            for (int word = 0; word < LINE_WORDS; word++)
                pending_read_line[word * DATA_WIDTH +: DATA_WIDTH] =
                    mem[pending_base_word + word];
        end
    end

    initial begin
        if (DATA_WIDTH != 32) $fatal(1, "DATA_WIDTH must be 32");
        if (LINE_WORDS < 2) $fatal(1, "LINE_WORDS must be at least two");
        if ((LINE_WORDS & (LINE_WORDS - 1)) != 0)
            $fatal(1, "LINE_WORDS must be a power of two");
        if (DEPTH_WORDS < LINE_WORDS)
            $fatal(1, "DEPTH_WORDS must contain at least one line");
        if ((DEPTH_WORDS % LINE_WORDS) != 0)
            $fatal(1, "DEPTH_WORDS must be a multiple of LINE_WORDS");
        if (LATENCY < 1) $fatal(1, "LATENCY must be at least one cycle");

        for (int word = 0; word < DEPTH_WORDS; word++) mem[word] = '0;
        if (HEX_FILE != "") $readmemh(HEX_FILE, mem);
    end

    // A normal clocked block is used because mem is also initialized above.
    // always_ff would require this block to be the array's only writer.
    always @(posedge clk) begin
        if (rst) begin
            state          <= MEMORY_IDLE;
            pending_write  <= 1'b0;
            pending_addr   <= '0;
            pending_wdata  <= '0;
            pending_fault  <= 1'b0;
            cycles_left    <= '0;
            resp_valid     <= 1'b0;
            resp_rdata     <= '0;
            resp_fault     <= 1'b0;
        end
        else begin
            case (state)
                MEMORY_IDLE: begin
                    if (req_valid && req_ready) begin
                        pending_write <= req_write;
                        pending_addr  <= req_addr;
                        pending_wdata <= req_wdata;
                        pending_fault <= request_fault(req_addr);
                        cycles_left   <= COUNT_BITS'(LATENCY);
                        state         <= MEMORY_WAIT;
                    end
                end

                MEMORY_WAIT: begin
                    if (cycles_left > COUNT_BITS'(1))
                        cycles_left <= cycles_left - 1'b1;
                    else if (pending_write) begin
                        if (!pending_fault) begin
                            for (int word = 0; word < LINE_WORDS; word++)
                                mem[pending_base_word + word] <=
                                    pending_wdata[word * DATA_WIDTH +: DATA_WIDTH];
                        end

                        // Cache writebacks do not need a separate response.
                        state <= MEMORY_IDLE;
                    end
                    else begin
                        resp_valid <= 1'b1;
                        resp_rdata <= pending_read_line;
                        resp_fault <= pending_fault;
                        state      <= MEMORY_RESPONSE;
                    end
                end

                MEMORY_RESPONSE: begin
                    if (resp_valid && resp_ready) begin
                        resp_valid <= 1'b0;
                        resp_fault <= 1'b0;
                        state      <= MEMORY_IDLE;
                    end
                end

                default: begin
                    resp_valid <= 1'b0;
                    resp_fault <= 1'b0;
                    state      <= MEMORY_IDLE;
                end
            endcase
        end
    end

endmodule
