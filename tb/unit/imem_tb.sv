`timescale 1 ns / 100 ps

module imem_tb #(
    parameter int NUM_RANDOM_TESTS = 1000
);
    localparam int WORDS = 16;
    localparam logic [31:0] NOP = 32'h0000_0013;

    logic [31:0] address;
    logic [31:0] instruction;

    int errors = 0;
    logic address_in_range;
    int range_hits [0:1];
    int offset_hits [0:3];

    imem #(
        .WORDS   (WORDS),
        .HEX_FILE("")
    ) DUT (
        .address    (address),
        .instruction(instruction)
    );

    task automatic check_read(
        input logic [31:0] test_address,
        input logic [31:0] expected,
        input string       test_name
    );
        address = test_address;
        #1;

        if (instruction !== expected) begin
            $error(
                "%s: address=%h, expected instruction=%h, actual instruction=%h",
                test_name,
                test_address,
                expected,
                instruction
            );
            errors++;
        end
    endtask

    initial begin
        // Initialize memory directly so this unit test does not depend on a
        // simulator working directory or an external file path.
        for (int i = 0; i < WORDS; i++) begin
            DUT.mem[i] = $urandom;
        end

        check_read(32'd0,  DUT.mem[0], "word zero");
        check_read(32'd4,  DUT.mem[1], "word one");
        check_read(32'd8,  DUT.mem[2], "word two");
        check_read(32'd12, DUT.mem[3], "word three");

        // The current design ignores address[1:0]. These checks document that
        // all byte addresses within one 32-bit word select the same instruction.
        check_read(32'd5, DUT.mem[1], "low address bits ignored");

        check_read(WORDS * 4, NOP, "first out-of-range address");
        check_read(32'hffff_fffc, NOP, "large out-of-range address");

        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            logic [31:0] random_address;
            logic [31:0] expected;

            if ($urandom_range(0, 1)) begin
                random_address = ($urandom_range(0, WORDS - 1) * 4) +
                                 $urandom_range(0, 3);
            end else begin
                random_address = (WORDS * 4) + $urandom_range(0, 1024);
            end

            address_in_range = (random_address[31:2] < WORDS);
            expected = address_in_range ? DUT.mem[random_address[31:2]] : NOP;
            check_read(random_address, expected, $sformatf("random read %0d", i));
            range_hits[address_in_range]++;
            offset_hits[random_address[1:0]]++;
        end

        for (int i = 0; i <= 1; i++) begin
            if (range_hits[i] == 0) begin
                $error("Missing IMEM in-range coverage value %0d", i);
                errors++;
            end
        end

        for (int i = 0; i < 4; i++) begin
            if (offset_hits[i] == 0) begin
                $error("Missing IMEM byte-offset coverage value %0d", i);
                errors++;
            end
        end

        if (errors == 0) begin
            $display("PASS: imem_tb");
        end else begin
            $fatal(1, "FAIL: imem_tb completed with %0d error(s)", errors);
        end
    end
endmodule
