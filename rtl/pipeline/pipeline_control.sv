// =============================================================================
// pipeline_control.sv  --  control-hazard arbiter (branches, jumps, traps)
// Owner: control/memory section
// -----------------------------------------------------------------------------
// SINGLE owner of every pipeline-register enable/flush and of the PC redirect.
// The load_use_hazard_unit (partner's module) only *detects* the load-use case
// and raises load_use_stall; this module decides what the pipeline actually
// does with it. Keeping one driver per control signal avoids multi-driver
// conflicts at integration.
//
// Resolution model: branches and jumps are resolved in EX (predict-not-taken),
// so a taken transfer must squash the two instructions already fetched behind
// it (now sitting in ID and IF) -> flush BOTH if_id and id_ex. That is the
// standard 2-cycle penalty. (Resolving JAL in ID would cut it to 1 cycle; left
// as a later optimization.)
//
// Priority:  trap  >  taken branch/jump  >  load-use stall
//   - trap outranks a branch: an exception on the older instruction wins.
//   - a redirect outranks a stall: the stalled slots are on the wrong path.
// =============================================================================
module pipeline_control (
  // ---- control-transfer resolution (from EX / partner's branch logic) -------
  input  logic        ex_redirect,    // taken branch OR jal/jalr, resolved in EX
  input  logic [31:0] ex_target,      // redirect destination

  // ---- load-use hazard (from load_use_hazard_unit) --------------------------
  input  logic        load_use_stall,

  // ---- trap / fault (v1 aggregate; refine with the CSR module) --------------
  input  logic        trap_req,       // exception detected this cycle
  input  logic [31:0] trap_target,    // mtvec base (stub until CSRs land)

  // ---- to PC / fetch --------------------------------------------------------
  output logic        pc_redirect,    // override sequential PC with pc_target
  output logic [31:0] pc_target,
  output logic        pc_stall,       // hold PC (load-use)

  // ---- to pipeline registers ------------------------------------------------
  output logic        stall_if_id,    // hold IF/ID  (load-use)
  output logic        flush_if_id,    // bubble IF/ID (redirect/trap)
  output logic        flush_id_ex     // bubble ID/EX (redirect / load-use bubble / trap)
);
  always_comb begin
    // defaults: pipeline advances normally
    pc_redirect = 1'b0;
    pc_target   = 32'b0;
    pc_stall    = 1'b0;
    stall_if_id = 1'b0;
    flush_if_id = 1'b0;
    flush_id_ex = 1'b0;

    if (trap_req) begin
      // Redirect to the trap vector and squash the front of the pipe.
      // NOTE: capturing mepc/mcause and squashing the faulting instruction in
      // its own stage (precise exceptions) is the CSR follow-up; this is the
      // minimal redirect+flush hook.
      pc_redirect = 1'b1;
      pc_target   = trap_target;
      flush_if_id = 1'b1;
      flush_id_ex = 1'b1;
    end
    else if (ex_redirect) begin
      // Taken branch/jump in EX: redirect fetch, kill the two wrong-path
      // instructions now in ID (-> flush_id_ex) and IF (-> flush_if_id).
      pc_redirect = 1'b1;
      pc_target   = ex_target;
      flush_if_id = 1'b1;
      flush_id_ex = 1'b1;
    end
    else if (load_use_stall) begin
      // Freeze PC + IF/ID, inject one bubble into EX.
      pc_stall    = 1'b1;
      stall_if_id = 1'b1;
      flush_id_ex = 1'b1;
    end
  end
endmodule