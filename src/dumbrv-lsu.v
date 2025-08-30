
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_lsu (
  input         clk,
  input         rst_n,
  // data SPI
  output        spi_data_mosi,
  input         spi_data_miso,
  output        spi_data_cs,
  output        spi_data_sck,
  // work from execute
  input         valid_i,
  input  [ 3:0] opcode_i,
  input  [31:0] addr_i,
  input  [31:0] data_i,
  input  [ 3:0] dreg_i,
  output        accept_o,
  // write back
  output [ 3:0] wb_dreg_o,
  output [31:0] wb_data_o,
  input         wb_done_i,
  output [ 3:0] pending_dreg, // pending load
  // instruction memory read
  output        imem_en_o,
  output [15:0] imem_addr_o,
  output [ 2:0] imem_size_o,
  input  [31:0] imem_data_i,
  input         imem_done_i,
  // stray memory requests
  output        stray_en_o,
  output        stray_wr_o,
  output [15:0] stray_addr_o,
  output [ 2:0] stray_size_o,
  output [31:0] stray_data_o,
  input  [31:0] stray_data_i,
  input         stray_done_i
  );

  reg accept = 0;
  assign accept_o = accept;

  localparam [2:0] STATE_IDLE  = 0;
  localparam [2:0] STATE_IMEM  = 2;
  localparam [2:0] STATE_DMEM  = 4;
  localparam [2:0] STATE_STRAY = 3;
  localparam [2:0] STATE_WB    = 7;

  reg [2:0] state = 0;

  reg is_store;
  reg is_signed;
  reg is_half;
  reg is_byte;
  reg [3:0] [7:0] data;
  reg [15:0] addr;
  reg [ 3:0] dreg;

  wire [2:0] size = is_byte ? 1 : is_half ? 2 : 4;
  wire [3:0] [7:0] proper_data =
      size == 1 ? { is_signed ? {24{data[0][7]}} : 24'b0, data[  0] } :
      size == 2 ? { is_signed ? {16{data[1][7]}} : 16'b0, data[1:0] } : data;

  // write back data wires
  assign wb_dreg_o    = state == STATE_WB ? dreg : 0;
  assign wb_data_o    = proper_data;

  wire pending_valid = (state != STATE_IDLE) && !is_store;
  assign pending_dreg = pending_valid ? dreg : 0;

  // index of dmem write
  reg [2:0] write_index = 0;

  assign imem_en_o   = state == STATE_IMEM;
  assign imem_addr_o = addr[15:0];
  assign imem_size_o = size;

  assign stray_en_o   = state == STATE_STRAY;
  assign stray_addr_o = addr[15:0];
  assign stray_size_o = size;
  assign stray_wr_o   = is_store;
  assign stray_data_o = data;

  wire       spi_done;
  wire [7:0] spi_data;

  reg spi_valid = 0;

  dumbrv_spi spi (
    .clk      ( clk                ),
    .rst_n    ( rst_n              ),
    // instruction SPI
    .spi_mosi ( spi_data_mosi      ),
    .spi_miso ( spi_data_miso      ),
    .spi_cs   ( spi_data_cs        ),
    .spi_sck  ( spi_data_sck       ),
    // controls
    .valid_i  ( spi_valid          ),
    .iswr_i   ( is_store           ),
    .addr_i   ( addr + write_index ),
    .data_i   ( data[write_index]  ),
    // read value
    .done_o   ( spi_done           ),
    .data_o   ( spi_data           )
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= STATE_IDLE;
      accept      <= 0;
      write_index <= 0;
    end else begin
      if (accept) begin
        accept <= 0;
      end
      case (state)
        STATE_IDLE: begin
          if (valid_i && !accept) begin
            is_store    <= opcode_i[3];
            is_signed   <= opcode_i[2];
            is_half     <= opcode_i[1];
            is_byte     <= opcode_i[0];
            data        <= data_i;
            dreg        <= dreg_i;
            addr        <= addr_i[15:0];
            accept      <= 1;
            write_index <= 0;
            if (dreg_i != 0 || opcode_i[3]) begin
              case (addr_i[31:24])
                8'h00: begin
                  if (!opcode_i[3]) begin
                    state <= STATE_IMEM;
                  end
                end
                8'h01: begin
                  state <= STATE_DMEM;
                end
                8'h02: begin
                  state <= STATE_STRAY;
                end
                default: begin
                  // BAD
                end
              endcase
            end
          end
        end
        STATE_STRAY: begin
          if (stray_done_i) begin
            data  <= stray_data_i;
            state <= is_store ? STATE_IDLE : STATE_WB;
          end
        end
        STATE_IMEM: begin
          if (imem_done_i) begin
            data  <= imem_data_i;
            state <= STATE_WB;
          end
        end
        STATE_DMEM: begin
          if (!spi_valid) begin
            spi_valid <= 1;
          end else if (spi_done && spi_valid) begin
            data[write_index] <= spi_data;
            write_index <= write_index + 1;
            spi_valid <= 0;
            if (write_index == size - 1) begin
              state <= is_store ? STATE_IDLE : STATE_WB;
            end
          end
        end
        STATE_WB: begin
          if (wb_done_i) begin
            state <= STATE_IDLE;
          end
        end
        default: begin
          // BAD
        end
      endcase
    end
  end

endmodule
