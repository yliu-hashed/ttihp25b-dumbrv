
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_alu (
  // inst input
  input  [31:0] val1_i,
  input  [31:0] val2_i,
  input  [31:0] val3_i,
  input  [ 5:0] op_i,
  // resteer control
  output        resteer_en_o,
  output [15:1] resteer_addr_o,
  // inst output
  output [31:0] val1_o,
  output [31:0] val2_o,
  output [31:0] val3_o,
  output [ 5:0] op_o,
  output        done_o
  );

  parameter SHIFT_CNT = 2;
  localparam SHIFT_BTS = $clog2(SHIFT_CNT+1);

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

  wire        [31:0] uval1 = val1_i;
  wire        [31:0] uval2 = val2_i;
  wire signed [31:0] sval1 = val1_i;
  wire signed [31:0] sval2 = val2_i;

  reg [31:0] alu_val; // comb
  reg [31:0] val2; // comb
  reg        alu_done;
  assign done_o = alu_done;

  // alu group -----------------------------------------------------------------
  wire shift_done = uval2[4:0] <= SHIFT_CNT;
  wire [SHIFT_BTS-1:0] shift_cnt = shift_done ? uval2[SHIFT_BTS-1:0] : SHIFT_CNT;

  always @(*) begin // comb
    alu_done = 1;
    val2 = val2_i;
    casez (op_i)
      default: alu_val = uval1 + uval2;
      OP_SUB: alu_val = uval1 - uval2;
      OP_AND: alu_val = uval1 & uval2;
      OP_OR : alu_val = uval1 | uval2;
      OP_XOR: alu_val = uval1 ^ uval2;
      OP_ULT: alu_val = { 31'b0, uval1 < uval2};
      OP_SLT: alu_val = { 31'b0, sval1 < sval2};
      OP_SHL: begin
        alu_val = sval1 << shift_cnt;
        alu_done = shift_done;
        val2 = val2_i - SHIFT_CNT;
      end
      OP_SRL: begin
        alu_val = uval1 >> shift_cnt;
        alu_done = shift_done;
        val2 = val2_i - SHIFT_CNT;
      end
      OP_SRA: begin
        alu_val = sval1 >>> shift_cnt;
        alu_done = shift_done;
        val2 = val2_i - SHIFT_CNT;
      end
      // [Zicond]
      OP_CEZ: alu_val = (uval2 == 0) ? 32'b0 : uval1;
      OP_CNZ: alu_val = (uval2 != 0) ? 32'b0 : uval1;
      // [Zbs]
      OP_BCLR: alu_val = uval1 & ~(1 << uval2[4:0]);
      OP_BEXT: alu_val = { 31'b0, uval1[uval2[4:0]] };
      OP_BINV: alu_val = uval1 ^ (1 << uval2[4:0]);
      OP_BSET: alu_val = uval1 | (1 << uval2[4:0]);
    endcase
  end

  // jb group ------------------------------------------------------------------
  wire is_bcc = op_i[5:3] == OP_BCC_PREFIX;
  reg take_br; // comb
  always @(*) begin
    casez (op_i)
      default  : take_br = 0;
      OP_J     : take_br = 1;
      OP_BR_EQ : take_br = uval1 == uval2;
      OP_BR_NE : take_br = uval1 != uval2;
      OP_BR_GT : take_br = sval1 <  sval2;
      OP_BR_LE : take_br = sval1 >= sval2;
      OP_BR_UGT: take_br = uval1 <  uval2;
      OP_BR_ULE: take_br = uval1 >= uval2;
    endcase
  end

  // resteer control
  assign resteer_en_o = take_br;
  assign resteer_addr_o = val3_i[15:1];

  // ls group ------------------------------------------------------------------
  wire is_mem = op_i[5];

  wire ls_size_h = op_i[1];
  wire ls_size_b = op_i[0];

  wire is_wr   = op_i[3];
  wire is_sign = op_i[2];

  wire [5:0] ls_op = { 2'b10, is_wr, is_sign, ls_size_h, ls_size_b };

  // output --------------------------------------------------------------------

  assign op_o   = is_mem ? ls_op : 6'b0;
  assign val1_o = alu_val;
  assign val2_o = val2;
  assign val3_o = val3_i;

endmodule
