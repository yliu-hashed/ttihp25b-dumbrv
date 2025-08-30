
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_spi_read (
  input         clk,
  input         rst_n,
  // instruction SPI
  output        spi_mosi,
  input         spi_miso,
  output        spi_cs,
  output        spi_sck,
  // controls
  input         valid_i,
  input  [15:0] addr_i,

  output        done_o,
  output [ 7:0] data_o
  );

  reg [15:0] addr;
  reg [ 7:0] buffer;
  assign spi_mosi = buffer[7];
  assign data_o = buffer;

  reg sck = 0;
  reg cs  = 0;
  assign spi_sck = sck;
  assign spi_cs  = cs;

  reg cache_bit = 0;

  localparam [7:0] SPI_RCMD = 8'h03;
  localparam [7:0] SPI_WCMD = 8'h02;

  localparam [2:0] STATE_IDLE = 0;
  localparam [2:0] STATE_WCMD = 1;
  localparam [2:0] STATE_ADR1 = 2;
  localparam [2:0] STATE_ADR2 = 3;
  localparam [2:0] STATE_WORK = 4;
  localparam [2:0] STATE_BURN = 5;

  reg       dirty   = 0;
  reg [2:0] state   = STATE_IDLE;
  reg [5:0] counter = 0;

  assign done_o = (state == STATE_WORK) && (counter == 0);

  wire step_done = counter == 0 || (counter == 1 && sck);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dirty     <= 0;
      cs        <= 0;
      sck       <= 0;
      state     <= STATE_IDLE;
      counter   <= 0;
    end else begin
      if (!spi_cs) begin
        cs <= 1;
      end else begin
        if (sck) begin
          sck     <= 0;
          counter <= counter - 1;
          buffer  <= { buffer[6:0], cache_bit };
        end else if (counter != 0) begin
          sck       <= 1;
          cache_bit <= spi_miso;
        end

        case (state)
          STATE_IDLE: begin
            if (valid_i) begin
              dirty     <= 1;
              if (dirty && addr_i == addr) begin
                // continuous
                state   <= STATE_WORK;
                counter <= 8;
              end else if (dirty && addr_i >= addr && addr_i - addr <= 3) begin
                // burned
                state   <= STATE_BURN;
                counter <= (addr_i - addr) * 8;
                addr    <= addr_i;
              end else begin
                // fresh
                cs      <= 0;
                addr    <= addr_i;
                state   <= STATE_WCMD;
                buffer  <= SPI_RCMD;
                counter <= 8;
              end
            end
          end
          STATE_WCMD: begin
            if (!valid_i) begin
              state   <= STATE_IDLE;
              counter <= 0;
              cs      <= 0;
              dirty   <= 0;
            end else if (step_done) begin
              state   <= STATE_ADR1;
              buffer  <= addr[15:8];
              counter <= 8;
            end
          end
          STATE_ADR1: begin
            if (!valid_i) begin
              state   <= STATE_IDLE;
              counter <= 0;
              cs      <= 0;
              dirty   <= 0;
            end else if (step_done) begin
              state   <= STATE_ADR2;
              buffer  <= addr[7:0];
              counter <= 8;
            end
          end
          STATE_ADR2: begin
            if (!valid_i) begin
              state   <= STATE_IDLE;
              counter <= 0;
              cs      <= 0;
              dirty   <= 0;
            end else if (step_done) begin
              state   <= STATE_WORK;
              counter <= 8;
            end
          end
          STATE_WORK: begin
            if (counter != 0 && !valid_i) begin
              state   <= STATE_IDLE;
              counter <= 0;
              cs      <= 0;
              dirty   <= 0;
            end else if (step_done && !valid_i) begin
              state <= STATE_IDLE;
              addr  <= addr + 1;
            end
          end
          STATE_BURN: begin
            if (!valid_i) begin
              state   <= STATE_IDLE;
              counter <= 0;
              cs      <= 0;
              dirty   <= 0;
            end else if (step_done) begin
              state <= STATE_WORK;
              counter <= 8;
            end
          end
          default: begin
            // BAD
          end
        endcase
      end
    end
  end

endmodule
