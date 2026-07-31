`timescale 1ns/1ps

module commit_unit_tb;
    import rv32i_pkg::*;
    import ooo_pkg::*;

    localparam int CLK_PERIOD = 10;

    logic clk;
    logic rst;
    logic rob_valid;
    rob_commit_t rob_entry;
    logic rob_ready;
    logic map_commit_valid;
    arch_reg_t map_commit_arch;
    phys_reg_t map_commit_phys;
    logic free_release_valid;
    phys_reg_t free_release_phys;
    logic store_commit_valid;
    rob_tag_t store_commit_tag;
    logic store_commit_done;
    logic store_commit_fault;
    logic trap_valid;
    logic [31:0] trap_pc;
    exception_cause_t trap_cause;
    logic [31:0] trap_value;
    logic halt;
    retire_event_t retire;
    int errors;

    commit_unit dut (
        .clk                 (clk),
        .rst                 (rst),
        .rob_valid_i         (rob_valid),
        .rob_entry_i         (rob_entry),
        .rob_ready_o         (rob_ready),
        .map_commit_valid_o  (map_commit_valid),
        .map_commit_arch_o   (map_commit_arch),
        .map_commit_phys_o   (map_commit_phys),
        .free_release_valid_o(free_release_valid),
        .free_release_phys_o (free_release_phys),
        .store_commit_valid_o(store_commit_valid),
        .store_commit_tag_o  (store_commit_tag),
        .store_commit_done_i (store_commit_done),
        .store_commit_fault_i(store_commit_fault),
        .trap_valid_o        (trap_valid),
        .trap_pc_o           (trap_pc),
        .trap_cause_o        (trap_cause),
        .trap_value_o        (trap_value),
        .halt_o              (halt),
        .retire_o            (retire)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    function automatic rob_tag_t make_tag(
        input int generation,
        input int position
    );
        rob_tag_t tag;
        tag = '0;
        tag.generation = generation[ROB_GENERATION_BITS-1:0];
        tag.position = position[ROB_POSITION_BITS-1:0];
        return tag;
    endfunction

    function automatic rob_commit_t make_entry(
        input uop_class_t uop_class,
        input int sequence_number
    );
        rob_commit_t entry;
        entry = ROB_ENTRY_EMPTY;
        entry.valid = 1'b1;
        entry.complete = 1'b1;
        entry.rob_tag = make_tag(0, sequence_number);
        entry.pc = sequence_number * 4;
        entry.instruction = 32'h0010_0093 + sequence_number;
        entry.uop_class = uop_class;
        entry.writes_rd = 1'b1;
        entry.rd_arch = arch_reg_t'((sequence_number % 31) + 1);
        entry.rd_phys = phys_reg_t'((sequence_number % 31) + 32);
        entry.stale_rd_phys = phys_reg_t'((sequence_number % 31) + 1);
        entry.result = 32'h5000_0000 + sequence_number;
        entry.memory_address_valid = 1'b1;
        entry.memory_address = 32'h0000_0100 + (sequence_number * 4);
        entry.store_data = 32'ha000_0000 + sequence_number;
        entry.mem_size = MEM_WORD;
        return entry;
    endfunction

    task automatic clear_inputs();
        rob_valid = 1'b0;
        rob_entry = ROB_ENTRY_EMPTY;
        store_commit_done = 1'b0;
        store_commit_fault = 1'b0;
    endtask

    task automatic reset_dut();
        clear_inputs();
        rst = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        #1;
    endtask

    task automatic check_bit(
        input logic actual,
        input logic expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected %b, got %b", name, expected, actual);
            errors++;
        end
    endtask

    task automatic check_word(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string name
    );
        if (actual !== expected) begin
            $error("%s: expected %08h, got %08h", name, expected, actual);
            errors++;
        end
    endtask

    task automatic present_entry(input rob_commit_t entry);
        @(negedge clk);
        rob_entry = entry;
        rob_valid = 1'b1;
        #1;
    endtask

    task automatic accept_entry();
        @(posedge clk);
        #1;
        rob_valid = 1'b0;
        rob_entry = ROB_ENTRY_EMPTY;
        store_commit_done = 1'b0;
        store_commit_fault = 1'b0;
    endtask

    task automatic check_no_register_side_effects(input string name);
        check_bit(map_commit_valid, 1'b0,
                  $sformatf("%s map commit", name));
        check_bit(free_release_valid, 1'b0,
                  $sformatf("%s free release", name));
    endtask

    initial begin
        rob_commit_t entry;
        rob_tag_t held_store_tag;

        errors = 0;
        rst = 1'b0;
        reset_dut();

        check_bit(rob_ready, 1'b0, "rob_ready while no entry is valid");
        check_bit(retire.valid, 1'b0, "retire invalid after reset");
        check_bit(trap_valid, 1'b0, "trap invalid after reset");
        check_bit(halt, 1'b0, "halt invalid after reset");
        check_no_register_side_effects("reset");
        check_bit(store_commit_valid, 1'b0, "reset store request");

        // Normal register retirement updates the committed map, frees the old
        // physical destination, and produces one architectural retire event.
        entry = make_entry(UOP_ALU, 1);
        present_entry(entry);
        check_bit(rob_ready, 1'b1, "normal register rob_ready");
        check_bit(map_commit_valid, 1'b1, "normal map commit");
        check_bit(free_release_valid, 1'b1, "normal stale release");
        check_bit(retire.valid, 1'b1, "normal retire valid");
        check_bit(retire.writes_rd, 1'b1, "normal retire writes rd");
        check_word(retire.pc, entry.pc, "normal retire PC");
        check_word(retire.rd_value, entry.result, "normal retire value");
        if ((map_commit_arch !== entry.rd_arch) ||
            (map_commit_phys !== entry.rd_phys) ||
            (free_release_phys !== entry.stale_rd_phys)) begin
            $error("Normal rename-map/free-list retirement payload mismatch");
            errors++;
        end
        accept_entry();

        // Instructions without an architectural destination retire without
        // touching either rename state structure.
        entry = make_entry(UOP_BRANCH, 2);
        entry.writes_rd = 1'b0;
        present_entry(entry);
        check_bit(rob_ready, 1'b1, "branch rob_ready");
        check_bit(retire.valid, 1'b1, "branch retire valid");
        check_bit(retire.writes_rd, 1'b0, "branch no destination");
        check_bit(map_commit_valid, 1'b0, "branch no map commit");
        check_bit(free_release_valid, 1'b0, "branch no free release");
        check_bit(store_commit_valid, 1'b0, "branch no store request");
        accept_entry();

        // A store remains at the ROB head until its exact D-cache transaction
        // finishes. Holding rob_valid must not create an early retire event.
        entry = make_entry(UOP_STORE, 3);
        entry.writes_rd = 1'b0;
        entry.mem_size = MEM_HALF;
        present_entry(entry);
        held_store_tag = store_commit_tag;
        check_bit(store_commit_valid, 1'b1, "store commit request");
        check_bit(rob_ready, 1'b0, "store waits for response");
        check_bit(retire.valid, 1'b0, "store does not retire early");
        if (held_store_tag !== entry.rob_tag) begin
            $error("Store request ROB tag mismatch");
            errors++;
        end

        repeat (3) begin
            @(posedge clk);
            #1;
            check_bit(store_commit_valid, 1'b1,
                      "store request held during back-pressure");
            check_bit(rob_ready, 1'b0,
                      "store head held during back-pressure");
            if (store_commit_tag !== held_store_tag) begin
                $error("Store tag changed before completion");
                errors++;
            end
        end

        @(negedge clk);
        store_commit_done = 1'b1;
        #1;
        check_bit(rob_ready, 1'b1, "successful store rob_ready");
        check_bit(retire.valid, 1'b1, "successful store retires");
        check_bit(retire.store_valid, 1'b1,
                  "successful store architectural event");
        check_word(retire.store_address, entry.memory_address,
                   "successful store address");
        check_word(retire.store_data, entry.store_data,
                   "successful store data");
        if (retire.store_size !== entry.mem_size) begin
            $error("Successful store size mismatch");
            errors++;
        end
        accept_entry();

        // A D-cache store fault traps precisely and exposes no register or
        // memory side effect.
        entry = make_entry(UOP_STORE, 4);
        entry.writes_rd = 1'b0;
        present_entry(entry);
        @(negedge clk);
        store_commit_done = 1'b1;
        store_commit_fault = 1'b1;
        #1;
        check_bit(rob_ready, 1'b1, "faulting store rob_ready");
        check_bit(trap_valid, 1'b1, "faulting store trap");
        check_bit(retire.valid, 1'b1, "faulting store retire event");
        check_bit(retire.exception_valid, 1'b1,
                  "faulting store exception event");
        check_bit(retire.store_valid, 1'b0,
                  "faulting store has no memory side effect");
        check_no_register_side_effects("faulting store");
        check_word(trap_pc, entry.pc, "faulting store trap PC");
        check_word(trap_value, entry.memory_address,
                   "faulting store trap value");
        if (trap_cause !== EXC_STORE_ACCESS_FAULT) begin
            $error("Faulting store cause mismatch");
            errors++;
        end
        accept_entry();

        // An exception recorded in the ROB suppresses destination commit and
        // becomes visible only when that entry reaches the head.
        entry = make_entry(UOP_LOAD, 5);
        entry.exception_valid = 1'b1;
        entry.exception_cause = EXC_LOAD_ACCESS_FAULT;
        entry.exception_value = 32'hdead_0100;
        present_entry(entry);
        check_bit(rob_ready, 1'b1, "exception rob_ready");
        check_bit(trap_valid, 1'b1, "recorded exception trap");
        check_bit(retire.valid, 1'b1, "recorded exception retire event");
        check_bit(retire.exception_valid, 1'b1,
                  "recorded exception metadata");
        check_bit(retire.writes_rd, 1'b0,
                  "recorded exception suppresses register write");
        check_no_register_side_effects("recorded exception");
        check_bit(store_commit_valid, 1'b0,
                  "recorded exception no store request");
        check_word(trap_pc, entry.pc, "recorded exception PC");
        check_word(trap_value, entry.exception_value,
                   "recorded exception value");
        if (trap_cause !== entry.exception_cause) begin
            $error("Recorded exception cause mismatch");
            errors++;
        end
        accept_entry();

        // EBREAK/halt retires no other side effect and raises the halt hook.
        entry = make_entry(UOP_SYSTEM, 6);
        entry.instruction = INSTRUCTION_EBREAK;
        entry.writes_rd = 1'b0;
        entry.halt = 1'b1;
        present_entry(entry);
        check_bit(rob_ready, 1'b1, "halt rob_ready");
        check_bit(halt, 1'b1, "halt output");
        check_bit(retire.valid, 1'b1, "halt retire event");
        check_bit(retire.halt, 1'b1, "halt retirement metadata");
        check_no_register_side_effects("halt");
        check_bit(store_commit_valid, 1'b0, "halt no store request");
        accept_entry();

        if (errors == 0)
            $display("PASS: commit_unit_tb");
        else
            $fatal(1, "FAIL: commit_unit_tb had %0d errors", errors);

        $finish;
    end

endmodule
