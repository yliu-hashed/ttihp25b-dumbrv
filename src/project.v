/*
 * Copyright (c) 2025 Yuanda Liu
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// ./tt/tt_tool.py --create-user-config --ihp
// ./tt/tt_tool.py --harden --ihp
// ./tt/tt_tool.py --create-png --ihp

module tt_um_dumbrv_yliu_hashed (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
  );

  assign uio_oe  = 8'b10111011;
  assign uio_out[2] = 0;
  assign uio_out[6] = 0;
  wire _unused = &{
    ena,
    uio_in[0], uio_in[1], uio_in[3],
    uio_in[4], uio_in[5], uio_in[7],
    1'b0
  };

  wire spi_inst_mosi;
  wire spi_inst_miso;
  wire spi_inst_cs;
  wire spi_inst_sck;

  assign uio_out[0] = !spi_inst_cs;
  assign uio_out[1] = spi_inst_mosi;
  assign spi_inst_miso = uio_in[2];
  assign uio_out[3] = spi_inst_sck;

  wire spi_data_mosi;
  wire spi_data_miso;
  wire spi_data_cs;
  wire spi_data_sck;

  assign uio_out[4] = !spi_data_cs;
  assign uio_out[5] = spi_data_mosi;
  assign spi_data_miso = uio_in[6];
  assign uio_out[7] = spi_data_sck;

  dumbrv_core core (
    .clk   (clk),
    .rst_n (rst_n),
    // instruction SPI
    .spi_inst_mosi ( spi_inst_mosi ),
    .spi_inst_miso ( spi_inst_miso ),
    .spi_inst_cs   ( spi_inst_cs   ),
    .spi_inst_sck  ( spi_inst_sck  ),
    // data SPI
    .spi_data_mosi ( spi_data_mosi ),
    .spi_data_miso ( spi_data_miso ),
    .spi_data_cs   ( spi_data_cs   ),
    .spi_data_sck  ( spi_data_sck  ),
    // general purpose inputs
    .gpio_i        ( ui_in       ),
    .gpio_o        ( uo_out      )
  );

endmodule
