`timescale 1 ns / 100 ps

module dmem_tb #(
    parameter int NUM_RANDOM_TESTS = 3000,
    parameter int DEPTH = 64
);
    import rv32i_pkg::*;

    logic        clk = 1'b0;
    logic [31:0] addr;
    logic [31:0] wr_data;
    logic [ 2:0] funct3;
    logic        mem_write;
    logic [31:0] rd_data;

    logic [31:0] model         [0:DEPTH-1];
    int          errors = 0;
    int          operation_hits[      0:7];
    int          byte_lane_hits[      0:3];

    dmem #(
        .DEPTH(DEPTH)
    ) DUT (
        .clk,
        .addr,
        .wr_data,
        .funct3,
        .mem_write,
        .rd_data
    );

    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    function automatic logic [31:0] model_read(input logic [31:0] test_addr, input logic [2:0] test_funct3);
        logic [31:0] word;
        logic [ 7:0] selected_byte;
        logic [15:0] selected_half;

        if (test_addr[31:2] >= DEPTH) begin
            return 32'b0;
        end

        word = model[test_addr[31:2]];
        selected_byte = word >> (test_addr[1:0] * 8);
        selected_half = test_addr[1] ? word[31:16] : word[15:0];

        case (test_funct3)
            LOAD_BYTE:   return {{24{selected_byte[7]}}, selected_byte};
            LOAD_HALF:   return {{16{selected_half[15]}}, selected_half};
            LOAD_WORD:   return word;
            LOAD_BYTE_U: return {24'b0, selected_byte};
            LOAD_HALF_U: return {16'b0, selected_half};
            default:     return 32'b0;
        endcase
    endfunction

    task automatic update_model(input logic [31:0] test_addr, input logic [31:0] test_data,
                                input logic [2:0] test_funct3);
        if (test_addr[31:2] < DEPTH) begin
            case (test_funct3)
                STORE_BYTE: begin
                    case (test_addr[1:0])
                        2'd0: model[test_addr[31:2]][7:0] = test_data[7:0];
                        2'd1: model[test_addr[31:2]][15:8] = test_data[7:0];
                        2'd2: model[test_addr[31:2]][23:16] = test_data[7:0];
                        2'd3: model[test_addr[31:2]][31:24] = test_data[7:0];
                    endcase
                end

                STORE_HALF: begin
                    if (test_addr[1]) begin
                        model[test_addr[31:2]][31:16] = test_data[15:0];
                    end else begin
                        model[test_addr[31:2]][15:0] = test_data[15:0];
                    end
                end

                STORE_WORD: model[test_addr[31:2]] = test_data;
                default: begin
                end
            endcase
        end
    endtask

    task automatic check_read(input logic [31:0] test_addr, input logic [2:0] test_funct3,
                              input string test_name);
        logic [31:0] expected;

        addr = test_addr;
        funct3 = test_funct3;
        mem_write = 1'b0;
        expected = model_read(test_addr, test_funct3);
        #1;

        if (rd_data !== expected) begin
            $error("%s: addr=%h funct3=%b expected=%h actual=%h", test_name, test_addr, test_funct3,
                   expected, rd_data);
            errors++;
        end
    endtask

    task automatic perform_write(input logic [31:0] test_addr, input logic [31:0] test_data,
                                 input logic [2:0] test_funct3);
        @(negedge clk);
        addr      <= test_addr;
        wr_data   <= test_data;
        funct3    <= test_funct3;
        mem_write <= 1'b1;
        @(posedge clk);
        update_model(test_addr, test_data, test_funct3);
        @(negedge clk);
        mem_write <= 1'b0;
    endtask

    initial begin : provide_stimulus
        for (int i = 0; i < DEPTH; i++) begin
            model[i] = '0;
        end

        addr      <= '0;
        wr_data   <= '0;
        funct3    <= LOAD_WORD;
        mem_write <= 1'b0;

        perform_write(32'd0, 32'h80ff_7f01, STORE_WORD);
        check_read(32'd0, LOAD_BYTE, "LB lane 0");
        check_read(32'd1, LOAD_BYTE, "LB lane 1");
        check_read(32'd2, LOAD_BYTE, "LB lane 2");
        check_read(32'd3, LOAD_BYTE, "LB lane 3");
        check_read(32'd0, LOAD_BYTE_U, "LBU lane 0");
        check_read(32'd3, LOAD_BYTE_U, "LBU lane 3");
        check_read(32'd0, LOAD_HALF, "LH lower");
        check_read(32'd2, LOAD_HALF, "LH upper");
        check_read(32'd0, LOAD_HALF_U, "LHU lower");
        check_read(32'd2, LOAD_HALF_U, "LHU upper");
        check_read(32'd0, LOAD_WORD, "LW");

        for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
            logic [31:0] random_addr;
            logic [31:0] random_data;
            logic [ 2:0] random_funct3;

            random_addr = ($urandom_range(0, DEPTH - 1) * 4) + $urandom_range(0, 3);
            random_data = $urandom;

            if ($urandom_range(0, 1)) begin
                case ($urandom_range(
                    0, 2
                ))
                    0: random_funct3 = STORE_BYTE;
                    1: random_funct3 = STORE_HALF;
                    default: random_funct3 = STORE_WORD;
                endcase

                perform_write(random_addr, random_data, random_funct3);
            end else begin
                case ($urandom_range(
                    0, 4
                ))
                    0: random_funct3 = LOAD_BYTE;
                    1: random_funct3 = LOAD_HALF;
                    2: random_funct3 = LOAD_WORD;
                    3: random_funct3 = LOAD_BYTE_U;
                    default: random_funct3 = LOAD_HALF_U;
                endcase

                check_read(random_addr, random_funct3, $sformatf("random data-memory read %0d", i));
            end

            operation_hits[random_funct3]++;
            byte_lane_hits[random_addr[1:0]]++;
        end

        check_read(DEPTH * 4, LOAD_WORD, "out-of-range read");
        perform_write(DEPTH * 4, 32'hffff_ffff, STORE_WORD);
        check_read(32'd0, LOAD_WORD, "out-of-range write ignored");

        for (int lane = 0; lane < 4; lane++) begin
            if (byte_lane_hits[lane] == 0) begin
                $error("Missing data-memory byte-lane coverage %0d", lane);
                errors++;
            end
        end

        foreach (operation_hits[op]) begin
            if (((op == LOAD_BYTE) ||
                 (op == LOAD_HALF) ||
                 (op == LOAD_WORD) ||
                 (op == LOAD_BYTE_U) ||
                 (op == LOAD_HALF_U)) &&
                (operation_hits[op] == 0)) begin
                $error("Missing data-memory funct3 coverage %0d", op);
                errors++;
            end
        end

        if (errors == 0) begin
            $display("PASS: dmem_tb");
        end else begin
            $fatal(1, "FAIL: dmem_tb completed with %0d error(s)", errors);
        end

        disable generate_clock;
    end
endmodule
