package ooo_pkg;

    import rv32i_pkg::*;

    // ---------------------------------------------------------------------
    // Single-wide OOO sizing
    // ---------------------------------------------------------------------
    //
    // Keep these values powers of two where noted. All OOO modules use these
    // definitions so a physical-register tag or ROB tag never changes width
    // at a module boundary.

    localparam int OOO_XLEN                 = XLEN;
    localparam int ARCH_REG_COUNT           = NUM_REGISTERS;
    localparam int PHYS_REG_COUNT           = 64;
    localparam int ROB_ENTRIES              = 16;  // Must be a power of two.
    localparam int ISSUE_QUEUE_ENTRIES      = 8;
    localparam int MEMORY_QUEUE_ENTRIES     = 8;
    localparam int BRANCH_CHECKPOINTS       = ROB_ENTRIES;
    localparam int FREE_LIST_ENTRIES        = PHYS_REG_COUNT - ARCH_REG_COUNT;

    localparam int ARCH_REG_BITS = (ARCH_REG_COUNT <= 1)
                                   ? 1 : $clog2(ARCH_REG_COUNT);
    localparam int PHYS_REG_BITS = (PHYS_REG_COUNT <= 1)
                                   ? 1 : $clog2(PHYS_REG_COUNT);
    localparam int ROB_INDEX_BITS = (ROB_ENTRIES <= 1)
                                    ? 1 : $clog2(ROB_ENTRIES);
    localparam int ROB_POSITION_BITS = ROB_INDEX_BITS + 1;
    localparam int ROB_GENERATION_BITS = 2;
    localparam int ROB_TAG_BITS = ROB_GENERATION_BITS + ROB_POSITION_BITS;
    localparam int ISSUE_QUEUE_INDEX_BITS = (ISSUE_QUEUE_ENTRIES <= 1)
                                            ? 1 : $clog2(ISSUE_QUEUE_ENTRIES);
    localparam int MEMORY_QUEUE_INDEX_BITS = (MEMORY_QUEUE_ENTRIES <= 1)
                                             ? 1 : $clog2(MEMORY_QUEUE_ENTRIES);
    localparam int FREE_LIST_INDEX_BITS = (FREE_LIST_ENTRIES <= 1)
                                          ? 1 : $clog2(FREE_LIST_ENTRIES);
    localparam int FREE_LIST_PTR_BITS = FREE_LIST_INDEX_BITS + 1;

    typedef logic [ARCH_REG_BITS-1:0]         arch_reg_t;
    typedef logic [PHYS_REG_BITS-1:0]         phys_reg_t;
    typedef logic [PHYS_REG_COUNT-1:0]        phys_reg_mask_t;
    typedef logic [ROB_INDEX_BITS-1:0]        rob_index_t;
    typedef logic [ROB_POSITION_BITS-1:0]     rob_position_t;
    typedef struct packed {
        logic [ROB_GENERATION_BITS-1:0] generation;
        rob_position_t                  position;
    } rob_tag_t;
    typedef logic [ISSUE_QUEUE_INDEX_BITS-1:0] issue_queue_index_t;
    typedef logic [MEMORY_QUEUE_INDEX_BITS-1:0] memory_queue_index_t;
    typedef logic [FREE_LIST_PTR_BITS-1:0]    free_list_ptr_t;

    // p0 is permanently ready and contains zero. The initial rename map uses
    // p0-p31 for x0-x31, leaving p32 and above in the free list.
    localparam arch_reg_t ARCH_ZERO = arch_reg_t'(0);
    localparam phys_reg_t PHYS_ZERO = phys_reg_t'(0);

    // ---------------------------------------------------------------------
    // Micro-operation controls
    // ---------------------------------------------------------------------

    typedef enum logic [3:0] {
        UOP_ALU    = 4'd0,
        UOP_BRANCH = 4'd1,
        UOP_JUMP   = 4'd2,
        UOP_LOAD   = 4'd3,
        UOP_STORE  = 4'd4,
        UOP_MULDIV = 4'd5,
        UOP_FENCE  = 4'd6,
        UOP_SYSTEM = 4'd7
    } uop_class_t;

    typedef enum logic [1:0] {
        OPERAND_A_RS1  = 2'd0,
        OPERAND_A_PC   = 2'd1,
        OPERAND_A_ZERO = 2'd2
    } operand_a_sel_t;

    typedef enum logic [1:0] {
        OPERAND_B_RS2  = 2'd0,
        OPERAND_B_IMM  = 2'd1,
        OPERAND_B_FOUR = 2'd2
    } operand_b_sel_t;

    typedef enum logic [1:0] {
        CONTROL_FLOW_NONE     = 2'd0,
        CONTROL_FLOW_BRANCH   = 2'd1,
        CONTROL_FLOW_DIRECT   = 2'd2,
        CONTROL_FLOW_INDIRECT = 2'd3
    } control_flow_t;

    // The numeric values match the synchronous exception codes written to
    // mcause. exception_valid distinguishes "no exception" from cause zero.
    typedef enum logic [3:0] {
        EXC_INSTRUCTION_ADDRESS_MISALIGNED = 4'd0,
        EXC_INSTRUCTION_ACCESS_FAULT       = 4'd1,
        EXC_ILLEGAL_INSTRUCTION            = 4'd2,
        EXC_BREAKPOINT                     = 4'd3,
        EXC_LOAD_ADDRESS_MISALIGNED        = 4'd4,
        EXC_LOAD_ACCESS_FAULT              = 4'd5,
        EXC_STORE_ADDRESS_MISALIGNED       = 4'd6,
        EXC_STORE_ACCESS_FAULT             = 4'd7,
        EXC_ECALL_FROM_M_MODE              = 4'd11
    } exception_cause_t;

    // ---------------------------------------------------------------------
    // Frontend and rename payloads
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic        valid;
        logic        taken;
        logic [31:0] target;
    } branch_prediction_t;

    // One decoded architectural instruction before physical-register rename.
    typedef struct packed {
        logic               valid;
        logic [31:0]        pc;
        logic [31:0]        instruction;

        arch_reg_t          rs1_arch;
        arch_reg_t          rs2_arch;
        arch_reg_t          rd_arch;
        logic               uses_rs1;
        logic               uses_rs2;
        logic               writes_rd;

        logic [31:0]        immediate;
        uop_class_t         uop_class;
        alu_op_t            alu_op;
        muldiv_op_t         muldiv_op;
        branch_op_t         branch_op;
        wb_sel_t            wb_sel;
        mem_size_t          mem_size;
        operand_a_sel_t     operand_a_sel;
        operand_b_sel_t     operand_b_sel;
        control_flow_t      control_flow;
        logic               load_unsigned;

        branch_prediction_t prediction;

        logic               halt;
        logic               exception_valid;
        exception_cause_t   exception_cause;
        logic [31:0]        exception_value;
    } decoded_uop_t;

    // A ROB tag contains a circular position and a generation. The position
    // provides age ordering; the generation changes when normal allocation
    // wraps or recovery rewinds the tail. A completion must match the complete
    // tag before it may update an entry. This keeps a late response from a
    // squashed operation from completing a reused slot after recovery.
    typedef struct packed {
        decoded_uop_t decoded;
        rob_tag_t     rob_tag;

        phys_reg_t    rs1_phys;
        phys_reg_t    rs2_phys;
        phys_reg_t    rd_phys;
        phys_reg_t    stale_rd_phys;
        logic         has_phys_destination;
    } renamed_uop_t;

    typedef struct packed {
        logic        used;
        logic        ready;
        phys_reg_t   tag;
        logic [31:0] value;
    } source_operand_t;

    // This is the payload stored by an issue or memory queue after rename.
    typedef struct packed {
        renamed_uop_t  uop;
        source_operand_t source_1;
        source_operand_t source_2;
    } dispatch_packet_t;

    typedef struct packed {
        renamed_uop_t uop;
        logic [31:0]  source_1_value;
        logic [31:0]  source_2_value;
    } execution_request_t;

    // ---------------------------------------------------------------------
    // Completion, branch recovery, and ROB payloads
    // ---------------------------------------------------------------------

    // Every execution producer uses this payload. A single result arbiter
    // places at most one completion on the common result bus per cycle.
    typedef struct packed {
        logic               valid;
        rob_tag_t           rob_tag;

        logic               writes_phys;
        phys_reg_t          rd_phys;
        logic [31:0]        result;

        logic               memory_address_valid;
        logic [31:0]        memory_address;
        logic [31:0]        store_data;

        logic               branch_valid;
        logic               branch_taken;
        logic               branch_mispredicted;
        logic [31:0]        branch_target;

        logic               exception_valid;
        exception_cause_t   exception_cause;
        logic [31:0]        exception_value;
    } completion_t;

    typedef completion_t result_bus_t;

    typedef struct packed {
        logic        valid;
        rob_tag_t    branch_tag;
        logic        taken;
        logic        mispredicted;
        logic [31:0] target;
    } branch_resolution_t;

    // Recovery preserves the branch and every older instruction. Structures
    // must invalidate only entries younger than branch_tag.
    typedef struct packed {
        logic        valid;
        rob_tag_t    branch_tag;
        logic [31:0] redirect_pc;
    } recovery_event_t;

    typedef struct packed {
        logic               valid;
        logic               complete;
        rob_tag_t           rob_tag;

        logic [31:0]        pc;
        logic [31:0]        instruction;
        uop_class_t         uop_class;

        logic               writes_rd;
        arch_reg_t          rd_arch;
        phys_reg_t          rd_phys;
        phys_reg_t          stale_rd_phys;
        logic [31:0]        result;

        logic               memory_address_valid;
        logic [31:0]        memory_address;
        logic [31:0]        store_data;
        mem_size_t          mem_size;
        logic               load_unsigned;

        logic               branch_taken;
        logic [31:0]        branch_target;

        logic               halt;
        logic               exception_valid;
        exception_cause_t   exception_cause;
        logic [31:0]        exception_value;
    } rob_entry_t;

    typedef rob_entry_t rob_commit_t;

    // ---------------------------------------------------------------------
    // Memory and retirement payloads
    // ---------------------------------------------------------------------

    typedef struct packed {
        logic        valid;
        rob_tag_t    rob_tag;
        logic        write;
        logic [31:0] address;
        logic [31:0] write_data;
        mem_size_t   mem_size;
        logic        load_unsigned;
    } memory_request_t;

    typedef struct packed {
        logic        valid;
        rob_tag_t    rob_tag;
        logic [31:0] read_data;
        logic        hit;
        logic        miss;
        logic        fault;
    } memory_response_t;

    // Architectural retirement event. It is useful for counters now and is
    // the stable observation point for the later UVM/Spike environment.
    typedef struct packed {
        logic               valid;
        logic [31:0]        pc;
        logic [31:0]        instruction;

        logic               writes_rd;
        arch_reg_t          rd_arch;
        logic [31:0]        rd_value;

        logic               store_valid;
        logic [31:0]        store_address;
        logic [31:0]        store_data;
        mem_size_t          store_size;

        logic               exception_valid;
        exception_cause_t   exception_cause;
        logic [31:0]        exception_value;
        logic               halt;
    } retire_event_t;

    // ---------------------------------------------------------------------
    // Empty payloads
    // ---------------------------------------------------------------------

    localparam branch_prediction_t BRANCH_PREDICTION_NONE = '0;
    localparam decoded_uop_t        DECODED_UOP_EMPTY      = '0;
    localparam renamed_uop_t        RENAMED_UOP_EMPTY      = '0;
    localparam source_operand_t     SOURCE_OPERAND_EMPTY   = '0;
    localparam dispatch_packet_t    DISPATCH_PACKET_EMPTY  = '0;
    localparam execution_request_t  EXECUTION_REQUEST_EMPTY = '0;
    localparam completion_t         COMPLETION_EMPTY       = '0;
    localparam branch_resolution_t  BRANCH_RESOLUTION_NONE = '0;
    localparam recovery_event_t     RECOVERY_EVENT_NONE    = '0;
    localparam rob_entry_t          ROB_ENTRY_EMPTY        = '0;
    localparam memory_request_t      MEMORY_REQUEST_EMPTY   = '0;
    localparam memory_response_t     MEMORY_RESPONSE_EMPTY  = '0;
    localparam retire_event_t        RETIRE_EVENT_EMPTY     = '0;

    // ---------------------------------------------------------------------
    // ROB tag helpers
    // ---------------------------------------------------------------------

    function automatic rob_index_t rob_index(input rob_tag_t tag);
        return tag.position[ROB_INDEX_BITS-1:0];
    endfunction

    function automatic rob_tag_t rob_next_tag(input rob_tag_t tag);
        rob_tag_t next_tag;

        next_tag = tag;
        next_tag.position = tag.position + rob_position_t'(1);
        if (tag.position == '1)
            next_tag.generation = tag.generation + 1'b1;

        return next_tag;
    endfunction

    // Recovery places the tail directly after the surviving branch and moves
    // to a new generation. The new instruction may reuse the same array slot
    // as a squashed instruction, but it can never reuse that instruction's
    // complete ROB tag.
    function automatic rob_tag_t rob_recovery_next_tag(input rob_tag_t branch_tag);
        rob_tag_t next_tag;

        next_tag.generation = branch_tag.generation + 1'b1;
        next_tag.position = branch_tag.position + rob_position_t'(1);
        return next_tag;
    endfunction

    // Returns one when candidate is younger than reference in the current
    // active ROB window. ROB_ENTRIES must be a power of two and no more than
    // ROB_ENTRIES instructions may be live at once.
    function automatic logic rob_is_younger(
        input rob_tag_t candidate,
        input rob_tag_t reference,
        input rob_tag_t head
    );
        int candidate_age;
        int reference_age;
        int tag_value_count;

        tag_value_count = 2 * ROB_ENTRIES;
        candidate_age = (int'(candidate.position) - int'(head.position) +
                         tag_value_count)
                        % tag_value_count;
        reference_age = (int'(reference.position) - int'(head.position) +
                         tag_value_count)
                        % tag_value_count;

        return candidate_age > reference_age;
    endfunction

endpackage
