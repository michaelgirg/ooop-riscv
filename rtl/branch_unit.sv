//Branch Unit

// This module will determine if a branch should be taken
// It will compare rs1_data and rs2_data based on the branch_op control signal
// The operations supported are BEQ, BNE, BLT, BGE, BLTU, and BGEU

// NOTE:
// This module only decides if the branch is taken and does not calculate the branch 
// target address. The PC logic uses the branch_taken singal together with branch_immediate to choose the next PC. 

module branch_unit (
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    input  logic [ 2:0] branch_op,
    output logic        branch_taken
);

    localparam logic [2:0] BR_NONE = 3'b000;
    localparam logic [2:0] BR_EQ = 3'b001;
    localparam logic [2:0] BR_NE = 3'b010;
    localparam logic [2:0] BR_LT = 3'b011;
    localparam logic [2:0] BR_GE = 3'b100;
    localparam logic [2:0] BR_LTU = 3'b101;
    localparam logic [2:0] BR_GEU = 3'b110;

    always_comb begin
        branch_taken = 1'b0;

        case (branch_op)
            BR_EQ:   branch_taken = (rs1_data == rs2_data);
            BR_NE:   branch_taken = (rs1_data != rs2_data);
            BR_LT:   branch_taken = ($signed(rs1_data) < $signed(rs2_data));
            BR_GE:   branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
            BR_LTU:  branch_taken = (rs1_data < rs2_data);
            BR_GEU:  branch_taken = (rs1_data >= rs2_data);
            BR_NONE: branch_taken = 1'b0;
            default: branch_taken = 1'b0;
        endcase
    end

endmodule
