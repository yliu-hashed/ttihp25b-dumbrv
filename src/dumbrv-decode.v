
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_decode (
  input  [31:0] inst_i,
  input  [31:1] pc_i,
  input         inst_was_short_i,

  // register port 1
  output [ 3:0] sreg1_reg_o,
  input  [31:0] sreg1_value_i,
  input         sreg1_valid_i,
  // register port 2
  output [ 3:0] sreg2_reg_o,
  input  [31:0] sreg2_value_i,
  input         sreg2_valid_i,

  output        incomplete_o,
  output [31:0] dec_val1_o,
  output [31:0] dec_val2_o,
  output [31:0] dec_val3_o,
  output [ 5:0] dec_op_o,
  output [ 3:0] dec_dreg_o
  );

  localparam [5:0] OP_NONE = 6'h00;
  localparam [5:0] OP_ADD  = 6'h00;
  localparam [5:0] OP_SUB  = 6'h01;
  localparam [5:0] OP_AND  = 6'h02;
  localparam [5:0] OP_OR   = 6'h03;
  localparam [5:0] OP_XOR  = 6'h04;
  localparam [5:0] OP_ULT  = 6'h05;
  localparam [5:0] OP_SLT  = 6'h06;
  localparam [5:0] OP_SHL  = 6'h07;
  localparam [5:0] OP_SRL  = 6'h08;
  localparam [5:0] OP_SRA  = 6'h09;

  localparam [5:0] OP_CEZ  = 6'h0A;
  localparam [5:0] OP_CNZ  = 6'h0B;

  localparam [5:0] OP_BCLR = 6'h0C;
  localparam [5:0] OP_BEXT = 6'h0D;
  localparam [5:0] OP_BINV = 6'h0E;
  localparam [5:0] OP_BSET = 6'h0F;

  localparam [5:0] OP_J      = { 3'b010, 3'h0 };

  localparam [2:0] OP_BCC_PREFIX = 3'b011;
  localparam [5:0] OP_BR_EQ  = { OP_BCC_PREFIX, 3'h0 };
  localparam [5:0] OP_BR_NE  = { OP_BCC_PREFIX, 3'h1 };
  localparam [5:0] OP_BR_GT  = { OP_BCC_PREFIX, 3'h4 };
  localparam [5:0] OP_BR_LE  = { OP_BCC_PREFIX, 3'h5 };
  localparam [5:0] OP_BR_UGT = { OP_BCC_PREFIX, 3'h6 };
  localparam [5:0] OP_BR_ULE = { OP_BCC_PREFIX, 3'h7 };

  // decode static bits --------------------------------------------------------
  wire [6:0] opcode = inst_i[6:0];
  wire [2:0] func3  = inst_i[14:12];
  wire [6:0] func7  = inst_i[31:25];

  // decode inst type ----------------------------------------------------------
  wire is_lui   = opcode == 7'b01101_11;
  wire is_auipc = opcode == 7'b00101_11;
  wire is_jal   = opcode == 7'b11011_11;
  wire is_jalr  = opcode == 7'b11001_11;
  wire is_bcc   = opcode == 7'b11000_11;
  wire is_lcc   = opcode == 7'b00000_11;
  wire is_scc   = opcode == 7'b01000_11;
  wire is_mcc   = opcode == 7'b00100_11;
  wire is_rcc   = opcode == 7'b01100_11; // including Zicond extension (czero.eqz and czero.nez)
  wire is_fen   = opcode == 7'b00011_11;

  wire is_xui = is_lui || is_auipc;

  // decode registers ----------------------------------------------------------
  wire [3:0] dreg  = inst_i[10: 7];
  wire [3:0] sreg1 = inst_i[18:15];
  wire [3:0] sreg2 = inst_i[23:20];

  wire use_dreg  = is_lui || is_auipc || is_jal || is_jalr || is_lcc || is_mcc || is_rcc;
  wire use_sreg1 = is_jalr || is_bcc || is_lcc || is_scc || is_mcc || is_rcc;
  wire use_sreg2 = is_bcc || is_scc || is_rcc;

  // decode inst imm -----------------------------------------------------------
  wire sign = inst_i[31];

  wire [31:0] simm_scc = { {20{sign}}, inst_i[31:25], inst_i[11:7] };
  wire [31:0] simm_bcc = { {19{sign}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0 };
  wire [31:0] simm_jal = { {11{sign}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0 };
  wire [31:0] simm_xui = { inst_i[31:12], 12'b0 };
  wire [31:0] simm_xxi = { {20{sign}}, inst_i[31:20] };

  wire [31:0] uimm_scc = { 20'b0, inst_i[31:25], inst_i[11:7] };
  wire [31:0] uimm_bcc = { 19'b0, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0 };
  wire [31:0] uimm_jal = { 11'b0, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0 };
  wire [31:0] uimm_xui = { inst_i[31:12], 12'b0 };
  wire [31:0] uimm_xxi = { 20'b0, inst_i[31:20] };

  // register file read --------------------------------------------------------
  assign sreg1_reg_o = sreg1;
  wire [31:0] sreg1_val = sreg1_value_i;
  wire sreg1_stall = (sreg1 != 4'b0) && use_sreg1 && !sreg1_valid_i;

  assign sreg2_reg_o = sreg2;
  wire [31:0] sreg2_val = sreg2_value_i;
  wire sreg2_stall = (sreg2 != 4'b0) && use_sreg2 && !sreg2_valid_i;

  assign incomplete_o = sreg1_stall || sreg2_stall;

  // xui group (auipc and lui) -------------------------------------------------
  wire        dec_xui      = is_auipc || is_lui;
  wire [31:0] dec_xui_val1 = is_auipc ? { pc_i, 1'b0 } : 0;
  wire [31:0] dec_xui_val2 = simm_xui;
  wire [ 5:0] dec_xui_op   = OP_ADD;

  // r and m group (register to register math functions) -----------------------
  wire [31:0] rm_sv2 = is_mcc ? simm_xxi : sreg2_val;
  wire [31:0] rm_uv2 = is_mcc ? uimm_xxi : sreg2_val;

  wire rm_op2_unsigned = func3 == 3'd5 || func3 == 3'd3 || func3 == 3'd1;
  wire [31:0] rm_v2 = rm_op2_unsigned ? rm_uv2 : rm_sv2;

  wire        dec_rm      = is_rcc || is_mcc;
  wire [31:0] dec_rm_val1 = sreg1_val;
  wire [31:0] dec_rm_val2 = rm_v2;
  reg  [ 5:0] dec_rm_op;

  always @(*) begin // comb for dec_rm_op
    casez ({ is_mcc, func7, func3 })
      default: dec_rm_op = 6'bxxxxx;
      // shifts
      11'b?_0000000_001: dec_rm_op = OP_SHL;
      11'b?_0000000_101: dec_rm_op = OP_SRL;
      11'b?_0100000_101: dec_rm_op = OP_SRA;
      // sub
      11'b0_0100000_000: dec_rm_op = OP_SUB;
      // long imm
      11'b0_0000000_000: dec_rm_op = OP_ADD;
      11'b1_???????_000: dec_rm_op = OP_ADD;
      11'b0_0000000_010: dec_rm_op = OP_SLT;
      11'b1_???????_010: dec_rm_op = OP_SLT;
      11'b0_0000000_011: dec_rm_op = OP_ULT;
      11'b1_???????_011: dec_rm_op = OP_ULT;
      11'b0_0000000_100: dec_rm_op = OP_XOR;
      11'b1_???????_100: dec_rm_op = OP_XOR;
      11'b0_0000000_110: dec_rm_op = OP_OR ;
      11'b1_???????_110: dec_rm_op = OP_OR ;
      11'b0_0000000_111: dec_rm_op = OP_AND;
      11'b1_???????_111: dec_rm_op = OP_AND;
      // [Zicond] conditional operations
      11'b0_0000111_111: dec_rm_op = OP_CNZ;
      11'b0_0000111_101: dec_rm_op = OP_CEZ;
      // [Zbs] single bit operation
      11'b?_0100100_001: dec_rm_op = OP_BCLR;
      11'b?_0100100_101: dec_rm_op = OP_BEXT;
      11'b?_0110100_001: dec_rm_op = OP_BINV;
      11'b?_0010100_001: dec_rm_op = OP_BSET;
    endcase
  end

  // j and b group (branch and jump) -------------------------------------------

  wire [31:0] jb_imm = is_bcc ? simm_bcc : is_jal ? simm_jal : simm_xxi;
  wire [31:0] jb_new_pc = (is_jalr ? sreg1_val : { pc_i, 1'b0 }) + jb_imm;

  wire        dec_jb = is_bcc || is_jal || is_jalr;
  wire [31:0] dec_jb_val1 = is_bcc  ? sreg1_val : { pc_i, 1'b0 };
  wire [31:0] dec_jb_val2 = is_bcc  ? sreg2_val : inst_was_short_i ? 32'h2 : 32'h4;
  wire [31:0] dec_jb_val3 = jb_new_pc;
  wire [ 5:0] dec_jb_op   = is_bcc ? { OP_BCC_PREFIX, func3 } : OP_J;
  wire        dec_jb_dreg = !is_bcc;

  // l and s group (load and store) --------------------------------------------
  wire ls_b = func3[1:0] == 2'b00;
  wire ls_h = func3[1:0] == 2'b01;
  wire ls_signed = !func3[2];

  wire        dec_ls = is_lcc || is_scc;
  wire [31:0] dec_ls_val1 = sreg1_val; // address
  wire [31:0] dec_ls_val2 = is_scc ? simm_scc : simm_xxi; // offset
  wire [31:0] dec_ls_val3 = sreg2_val; // data
  wire [ 5:0] dec_ls_op = { 2'b10, is_scc, ls_signed, ls_h, ls_b };
  wire        dec_ls_dreg = is_lcc;

  // output --------------------------------------------------------------------
  reg [ 5:0] dec_op;   // xui | rm  | bcc | jar | ls  |
  reg [31:0] dec_val1; // val | v1  | v1  | lk  | adr |
  reg [31:0] dec_val2; // imm | v2  | v2  | lko | off |
  reg [31:0] dec_val3; //  0  |  0  | tar | tar | val |
  reg        dec_dreg;

  assign dec_val1_o  = dec_val1;
  assign dec_val2_o  = dec_val2;
  assign dec_val3_o  = dec_val3;
  assign dec_op_o    = dec_op;
  assign dec_dreg_o  = dec_dreg ? dreg : 4'b0;

  always @(*) begin // comb
    if (dec_xui) begin
      dec_val1 = dec_xui_val1;
      dec_val2 = dec_xui_val2;
      dec_val3 = 32'b0;
      dec_op   = dec_xui_op;
      dec_dreg = 1;
    end else if (dec_rm) begin
      dec_val1 = dec_rm_val1;
      dec_val2 = dec_rm_val2;
      dec_val3 = 32'b0;
      dec_op   = dec_rm_op;
      dec_dreg = 1;
    end else if (dec_jb) begin
      dec_val1 = dec_jb_val1;
      dec_val2 = dec_jb_val2;
      dec_val3 = dec_jb_val3;
      dec_op   = dec_jb_op;
      dec_dreg = dec_jb_dreg;
    end else if (dec_ls) begin
      dec_val1 = dec_ls_val1;
      dec_val2 = dec_ls_val2;
      dec_val3 = dec_ls_val3;
      dec_op   = dec_ls_op;
      dec_dreg = dec_ls_dreg;
    end else begin
      dec_val1 = 32'hXXXXXXXX;
      dec_val2 = 32'hXXXXXXXX;
      dec_val3 = 32'hXXXXXXXX;
      dec_op   = 6'bXXXXXX;
      dec_dreg = 0;
    end
  end

endmodule
