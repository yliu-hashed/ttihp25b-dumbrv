
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_regs (
  input         clk,
  input         rst_n,

  input  [ 3:0] wr1_reg,
  input  [31:0] wr1_value,
  output        wr1_done,

  input  [ 3:0] wr2_reg,
  input  [31:0] wr2_value,
  output        wr2_done,

  input  [ 3:0] rd1_reg,
  output [31:0] rd1_value,

  input  [ 3:0] rd2_reg,
  output [31:0] rd2_value
  );

  localparam [2:0] STATE_IDLE  = 0;
  localparam [2:0] STATE_1WAIT = 2;
  localparam [2:0] STATE_1DONE = 3;
  localparam [2:0] STATE_2WAIT = 4;
  localparam [2:0] STATE_2DONE = 5;

  reg [2:0] state = STATE_IDLE;
  wire write = state == STATE_1WAIT || state == STATE_2WAIT;
  assign wr1_done = state == STATE_1DONE;
  assign wr2_done = state == STATE_2DONE;

  wire [31:0] values [15:0];
  assign values[0] = 0;
  reg [31:0] tmp;
  reg [ 3:0] wr_reg;

  assign rd1_value = values[rd1_reg];
  assign rd2_value = values[rd2_reg];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (wr1_reg != 0) begin
            state  <= STATE_1WAIT;
            tmp    <= wr1_value;
            wr_reg <= wr1_reg;
          end else if (wr2_reg != 0) begin
            state  <= STATE_2WAIT;
            tmp    <= wr2_value;
            wr_reg <= wr2_reg;
          end
        end
        STATE_1WAIT: begin
          state <= STATE_1DONE;
        end
        STATE_2WAIT: begin
          state <= STATE_2DONE;
        end
        STATE_1DONE: begin
          state <= STATE_IDLE;
        end
        STATE_2DONE: begin
          state <= STATE_IDLE;
        end
        default: begin
          // BAD
        end
      endcase
    end
  end

  genvar i;
  generate
    for (i = 1; i < 16; i = i + 1) begin
      reg [31:0] latch;
      assign values[i] = latch;

      (* keep *)
      reg we = 0;
      always @(tmp or we) begin
        if (we) latch <= tmp;
      end

      always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
          we <= 0;
        end else if (write && wr_reg == i) begin
          we <= 1;
        end else begin
          we <= 0;
        end
      end
    end
  endgenerate
endmodule
