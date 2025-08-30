
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_gpio (
  input         clk,
  input         rst_n,
  // stray memory requests
  input         stray_en_i,
  input         stray_wr_i,
  input  [15:0] stray_addr_i,
  input  [ 2:0] stray_size_i,
  input  [31:0] stray_data_i,
  output [31:0] stray_data_o,
  output        stray_done_o,
  // gpio
  input  [ 7:0] gpio_i,
  output [ 7:0] gpio_o
  );

  assign stray_done_o = 1;

  wire [3:0] [7:0] wr_data = stray_data_i;

  wire [3:0] byte_match;
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin
      wire [15:0] addr = -i;
      assign byte_match[i] = (stray_addr_i == addr) && stray_size_i > i;
    end
  endgenerate

  reg [7:0] gpo_data = 0;
  assign gpio_o = gpo_data;
  reg [3:0] [7:0] gpi_data;
  assign stray_data_o = gpi_data;

  always @(*) begin
    gpi_data = 0;
    if (byte_match[0]) gpi_data[0] = gpio_i;
    if (byte_match[1]) gpi_data[1] = gpio_i;
    if (byte_match[2]) gpi_data[2] = gpio_i;
    if (byte_match[3]) gpi_data[3] = gpio_i;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gpo_data <= 0;
    end else if (stray_en_i && stray_wr_i) begin
      casez (byte_match)
        4'b???1: gpo_data <= wr_data[0];
        4'b??1?: gpo_data <= wr_data[1];
        4'b?1??: gpo_data <= wr_data[2];
        4'b1???: gpo_data <= wr_data[3];
      endcase
    end
  end

endmodule
