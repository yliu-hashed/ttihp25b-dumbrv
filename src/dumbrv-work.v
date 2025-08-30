
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_work (
  input         clk,
  input         rst_n,
  // inst input
  input  [ 1:0] inst_size_i,
  input  [31:0] inst_i,
  input  [15:1] inst_addr_i,
  output        inst_use_o,
  output        inst_use_half_o,
  // resteer control
  output        resteer_en_o,
  output [15:1] resteer_addr_o,
  // work submission to LSU
  output        lsu_valid_o,
  output [ 3:0] lsu_opcode_o,
  output [31:0] lsu_addr_o,
  output [31:0] lsu_data_o,
  output [ 3:0] lsu_dreg_o,
  input         lsu_accept_i,
  // write back from LSU
  input  [ 3:0] lsu_wb_dreg_i,
  input  [31:0] lsu_wb_data_i,
  output        lsu_wb_done_o,
  input  [ 3:0] lsu_load_dreg
  );

  localparam [1:0] STATE_IDLE   = 0;
  localparam [1:0] STATE_DECODE = 1;
  localparam [1:0] STATE_ALU    = 2;
  localparam [1:0] STATE_SUBMIT = 3;

  reg [1:0] state = STATE_IDLE;

  reg        inst_was_short = 0;
  reg [31:0] val1;
  reg [31:0] val2;
  reg [31:0] val3;
  reg [ 5:0] op   = 6'b0;
  reg [ 3:0] dreg = 4'b0;

  // Fetch and expand (STATE_IDLE) ---------------------------------------------

  wire short;
  wire [31:0] inst_full;
  dumbrv_expand expand (
    .inst_i  ( inst_i    ),
    .inst_o  ( inst_full ),
    .short_o ( short     )
  );

  assign inst_use_half_o = short;

  wire can_use = (inst_size_i == 0 ? 0 :
                  inst_size_i == 1 ? short : 1);
  assign inst_use_o = can_use && state == STATE_IDLE;

  // Decode (STATE_DECODE) -----------------------------------------------------

  wire [ 3:0] sreg1_reg;
  wire [31:0] sreg1_value_reg;
  reg  [31:0] sreg1_value;
  reg         sreg1_valid;
  always @(*) begin
    if (sreg1_reg == 0) begin
      sreg1_valid = 1;
      sreg1_value = 0;
    end else if (sreg1_reg == lsu_load_dreg) begin
      sreg1_valid = 0;
      sreg1_value = 32'hXXXXXXXX;
    end else begin
      sreg1_valid = 1;
      sreg1_value = sreg1_value_reg;
    end
  end

  wire [ 3:0] sreg2_reg;
  wire [31:0] sreg2_value_reg;
  reg  [31:0] sreg2_value;
  reg         sreg2_valid;
  always @(*) begin
    if (sreg2_reg == 0) begin
      sreg2_valid = 1;
      sreg2_value = 0;
    end else if (sreg2_reg == lsu_load_dreg) begin
      sreg2_valid = 0;
      sreg2_value = 32'hXXXXXXXX;
    end else begin
      sreg2_valid = 1;
      sreg2_value = sreg2_value_reg;
    end
  end

  wire        dec_incomplete;
  wire [31:0] dec_val1;
  wire [31:0] dec_val2;
  wire [31:0] dec_val3;
  wire [ 5:0] dec_op;
  wire [ 3:0] dec_dreg;

  wire dreg_stall = (dec_dreg == lsu_load_dreg) && (dec_dreg != 0);

  dumbrv_decode decode (
    .inst_i           ( val1                   ),
    .pc_i             ( { 16'b0, val2[15:1] }  ),
    .inst_was_short_i ( inst_was_short         ),
    // register port 1
    .sreg1_reg_o      ( sreg1_reg              ),
    .sreg1_value_i    ( sreg1_value            ),
    .sreg1_valid_i    ( sreg1_valid            ),
    // register port 2
    .sreg2_reg_o      ( sreg2_reg              ),
    .sreg2_value_i    ( sreg2_value            ),
    .sreg2_valid_i    ( sreg2_valid            ),
    // outputs
    .incomplete_o     ( dec_incomplete         ),
    .dec_val1_o       ( dec_val1               ),
    .dec_val2_o       ( dec_val2               ),
    .dec_val3_o       ( dec_val3               ),
    .dec_op_o         ( dec_op                 ),
    .dec_dreg_o       ( dec_dreg               )
  );

  wire [ 3:0] wb1_reg   = lsu_wb_dreg_i;
  wire [31:0] wb1_value = lsu_wb_data_i;
  wire        wb1_done;
  assign lsu_wb_done_o = wb1_done;

  wire [ 3:0] wb2_reg   = (state == STATE_SUBMIT) && (op == 0) ? dreg : 0;
  wire [31:0] wb2_value = val1;
  wire        wb2_done;

  dumbrv_regs registers (
    .clk       ( clk             ),
    .rst_n     ( rst_n           ),

    .wr1_reg   ( wb1_reg         ),
    .wr1_value ( wb1_value       ),
    .wr1_done  ( wb1_done        ),

    .wr2_reg   ( wb2_reg         ),
    .wr2_value ( wb2_value       ),
    .wr2_done  ( wb2_done        ),

    .rd1_reg   ( sreg1_reg       ),
    .rd1_value ( sreg1_value_reg ),

    .rd2_reg   ( sreg2_reg       ),
    .rd2_value ( sreg2_value_reg )
  );

  // Math (STATE_ALU) ----------------------------------------------------------

  wire [31:0] alu_val1;
  wire [31:0] alu_val2;
  wire [31:0] alu_val3;
  wire [ 5:0] alu_op;
  wire        alu_done;

  dumbrv_alu alu (
    // inst input
    .val1_i ( val1     ),
    .val2_i ( val2     ),
    .val3_i ( val3     ),
    .op_i   ( op       ),
    // resteer control
    .resteer_en_o   ( resteer_en_o   ),
    .resteer_addr_o ( resteer_addr_o ),
    // inst output
    .val1_o ( alu_val1 ),
    .val2_o ( alu_val2 ),
    .val3_o ( alu_val3 ),
    .op_o   ( alu_op   ),
    .done_o ( alu_done )
  );

  // LSU -----------------------------------------------------------------------

  assign lsu_valid_o  = (state == STATE_SUBMIT) && op[5];
  assign lsu_opcode_o = op[3:0];
  assign lsu_addr_o   = val1;
  assign lsu_data_o   = val3;
  assign lsu_dreg_o   = dreg;

  // State Machine -------------------------------------------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      inst_was_short <= 0;
      op      <= 6'b0;
      dreg    <= 4'b0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (can_use) begin
            state <= STATE_DECODE;
            val1 <= inst_full;
            val2 <= { 16'b0, inst_addr_i, 1'b0 };
            inst_was_short <= short;
          end
        end
        STATE_DECODE: begin
          if (!dec_incomplete && !dreg_stall) begin
            state <= STATE_ALU;
            val1  <= dec_val1;
            val2  <= dec_val2;
            val3  <= dec_val3;
            op    <= dec_op;
            dreg  <= dec_dreg;
          end
        end
        STATE_ALU: begin
          val1  <= alu_val1;
          val2  <= alu_val2;
          val3  <= alu_val3;
          if (alu_done) begin
            op    <= alu_op;
            state <= STATE_SUBMIT;
          end
        end
        STATE_SUBMIT: begin
          if (!op[5] && (dreg == 0 || wb2_done)) begin
            state <= STATE_IDLE;
          end
          if (op[5] && lsu_accept_i) begin
            state <= STATE_IDLE;
          end
        end
      endcase
    end
  end

endmodule
