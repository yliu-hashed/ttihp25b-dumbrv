
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_fetch (
  input         clk,
  input         rst_n,
  // instruction SPI
  output        spi_inst_mosi,
  input         spi_inst_miso,
  output        spi_inst_cs,
  output        spi_inst_sck,
  // read instruction memory to LSU
  input         rd_en_i, // once enabled, request must never change until done
  input  [15:0] rd_addr_i,
  input  [ 2:0] rd_size_i,
  output [31:0] rd_data_o,
  output        rd_done_o,
  // resteer control
  input         resteer_en_i,
  input  [15:1] resteer_addr_i,
  // instruction output
  output [ 1:0] inst_size_o,
  output [31:0] inst_o,
  output [15:1] inst_addr_o,
  input         inst_use_i,
  input         inst_use_half_i
  );

  parameter QUEUE_SIZE = 6;
  parameter CONTINUOUS_INST_AT = 6;
  localparam QUEUE_BITS = $clog2(QUEUE_SIZE + 1);

  localparam [1:0] STATE_IDLE = 0;
  localparam [1:0] STATE_INST = 2;
  localparam [1:0] STATE_DATA = 3;

  reg [1:0] state = STATE_IDLE;

  reg [2:0] data_size;
  reg [3:0] [7:0] data;
  assign rd_data_o = data;

  reg [15:1] pc;
  wire [15:0] _pc = { pc, 1'b0 };

  reg [QUEUE_BITS-1:0] inst_size;
  reg [QUEUE_SIZE-1:0] [7:0] inst;
  assign inst_size_o = (inst_size[QUEUE_BITS-1:1] <= 2) ? inst_size[2:1] : 2;
  assign inst_o      = inst[3:0];
  assign inst_addr_o = pc;

  reg         cmd_valid = 0;
  wire [15:0] cmd_addr  = state == STATE_DATA ? (rd_addr_i + data_size) : ({ pc, 1'b0 } + inst_size);
  wire        cmd_done;
  wire [ 7:0] cmd_data;

  dumbrv_spi_read spi_reader (
    .clk      ( clk           ),
    .rst_n    ( rst_n         ),
    // instruction SPI
    .spi_mosi ( spi_inst_mosi ),
    .spi_miso ( spi_inst_miso ),
    .spi_cs   ( spi_inst_cs   ),
    .spi_sck  ( spi_inst_sck  ),
    // controls
    .valid_i  ( cmd_valid     ),
    .addr_i   ( cmd_addr      ),
    .done_o   ( cmd_done      ),
    .data_o   ( cmd_data      )
  );

  assign rd_done_o = (state == STATE_DATA) && (data_size == rd_size_i);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_valid    <= 0;
      state        <= STATE_IDLE;
      pc           <= 0;
      data_size    <= 0;
      inst_size    <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (resteer_en_i) begin
            state <= STATE_IDLE;
            pc <= resteer_addr_i;
            inst_size <= 0;
          end else if (inst_use_i) begin
            if (inst_use_half_i) begin
              inst_size <= inst_size - 2;
              inst <= { 16'b0, inst[QUEUE_SIZE-1:2] };
              pc   <= pc + 1;
            end else begin
              inst_size <= inst_size - 4;
              inst <= { 32'b0, inst[QUEUE_SIZE-1:4] };
              pc   <= pc + 2;
            end
          end else if (rd_en_i && inst_size >= CONTINUOUS_INST_AT) begin
            state     <= STATE_DATA;
            data_size <= 0;
            cmd_valid <= 1;
          end else if (inst_size < QUEUE_SIZE) begin
            state     <= STATE_INST;
            cmd_valid <= 1;
          end
        end
        STATE_INST: begin
          if (resteer_en_i) begin
            pc        <= resteer_addr_i;
            inst_size <= 0;
            state     <= STATE_IDLE;
            cmd_valid <= 0;
          end else if (inst_use_i) begin
            if (inst_use_half_i) begin
              inst_size <= inst_size - 2;
              inst <= { 16'b0, inst[QUEUE_SIZE-1:2] };
              pc   <= pc + 1;
            end else begin
              inst_size <= inst_size - 4;
              inst <= { 32'b0, inst[QUEUE_SIZE-1:4] };
              pc   <= pc + 2;
            end
          end else if (cmd_valid) begin
            if (cmd_done) begin
              cmd_valid <= 0;
              inst_size <= inst_size + 1;
              inst[inst_size] <= cmd_data;
            end
          end else if (!inst_size[0]) begin
            state <= STATE_IDLE;
          end else begin
            cmd_valid <= 1;
          end
        end
        STATE_DATA: begin
          if (resteer_en_i) begin
            pc <= resteer_addr_i;
            inst_size <= 0;
          end else if (inst_use_i) begin
            if (inst_use_half_i) begin
              inst_size <= inst_size - 2;
              inst <= { 16'b0, inst[QUEUE_SIZE-1:2] };
              pc   <= pc + 1;
            end else begin
              inst_size <= inst_size - 4;
              inst <= { 32'b0, inst[QUEUE_SIZE-1:4] };
              pc   <= pc + 2;
            end
          end
          if (cmd_valid) begin
            if (cmd_done) begin
              cmd_valid <= 0;
              data[data_size] <= cmd_data;
              data_size <= data_size + 1;
            end
          end else if (data_size == rd_size_i) begin
            if (!rd_en_i) begin
              state <= STATE_IDLE;
            end
          end else begin
            cmd_valid <= 1;
          end
        end
        default: begin
          // BAD
        end
      endcase
    end
  end

endmodule
