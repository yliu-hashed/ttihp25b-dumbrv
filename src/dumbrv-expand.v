
`timescale 1ns / 10ps
`default_nettype none

module dumbrv_expand (
  input  [31:0] inst_i,
  output [31:0] inst_o,
  output        short_o
  );

  wire short = ~&(inst_i[1:0]);
  assign short_o = short;

  wire [4:0] short_opcode = { inst_i[15:13], inst_i[1:0] };

  reg [31:0] inst;
  assign inst_o = inst;

  always @(*) begin
    if (short) begin
      case (short_opcode)
        5'b000_00: inst = { 2'b00, inst_i[10:7], inst_i[12:11], inst_i[5], inst_i[6], 2'b00, 5'd2, 3'b000, 2'b01, inst_i[4:2], 7'b0010011 };
        5'b010_00: inst = { 5'b00000, inst_i[5], inst_i[12:10], inst_i[6], 2'b00, 2'b01, inst_i[9:7], 3'b010, 2'b01, inst_i[4:2], 7'b0000011 };
        5'b110_00: inst = { 5'b00000, inst_i[5], inst_i[12], 2'b01, inst_i[4:2], 2'b01, inst_i[9:7], 3'b010, inst_i[11:10], inst_i[6], 2'b00, 7'b0100011 };
        5'b000_01: inst = { {7{inst_i[12]}}, inst_i[6:2], inst_i[11:7], 3'b000, inst_i[11:7], 7'b0010011 };
        5'b001_01: inst = { inst_i[12], inst_i[8], inst_i[10:9], inst_i[6], inst_i[7], inst_i[2], inst_i[11], inst_i[5:3], inst_i[12], {8{inst_i[12]}}, 5'd1, 7'b1101111 };
        5'b010_01: inst = { {7{inst_i[12]}}, inst_i[6:2], 5'd0, 3'b000, inst_i[11:7], 7'b0010011 };
        5'b011_01: begin
          if (inst_i[11:7] == 5'd2) begin
            inst = { {3{inst_i[12]}}, inst_i[4], inst_i[3], inst_i[5], inst_i[2], inst_i[6], 4'b0000, 5'd2, 3'b000, 5'd2, 7'b0010011 };
          end else begin
            inst = { {15{inst_i[12]}}, inst_i[6:2], inst_i[11:7], 7'b0110111 };
          end
        end
        5'b10001: begin
          casez ({ inst_i[12:10], inst_i[6:5] })
            5'b011_00: inst = { 7'b0100000     , 2'b01, inst_i[4:2], 2'b01, inst_i[9:7], 3'b000, 2'b01, inst_i[9:7], 7'b0110011 };
            5'b011_01: inst = { 7'b0000000     , 2'b01, inst_i[4:2], 2'b01, inst_i[9:7], 3'b100, 2'b01, inst_i[9:7], 7'b0110011 };
            5'b011_10: inst = { 7'b0000000     , 2'b01, inst_i[4:2], 2'b01, inst_i[9:7], 3'b110, 2'b01, inst_i[9:7], 7'b0110011 };
            5'b011_11: inst = { 7'b0000000     , 2'b01, inst_i[4:2], 2'b01, inst_i[9:7], 3'b111, 2'b01, inst_i[9:7], 7'b0110011 };
            5'b?10_??: inst = { {7{inst_i[12]}}, inst_i[6:2]       , 2'b01, inst_i[9:7], 3'b111, 2'b01, inst_i[9:7], 7'b0010011 };
            5'b?00_??: inst = { 7'b0000000     , inst_i[6:2]       , 2'b01, inst_i[9:7], 3'b101, 2'b01, inst_i[9:7], 7'b0010011 };
            5'b?01_??: inst = { 7'b0100000     , inst_i[6:2]       , 2'b01, inst_i[9:7], 3'b101, 2'b01, inst_i[9:7], 7'b0010011 };
            default:   inst = 32'bXXXXXXXX;
          endcase
        end
        5'b101_01: inst = { inst_i[12], inst_i[8], inst_i[10:9], inst_i[6], inst_i[7], inst_i[2], inst_i[11], inst_i[5:3], inst_i[12], {8{inst_i[12]}}, 5'd0, 7'b1101111 };
        5'b110_01: inst = { {4{inst_i[12]}}, inst_i[6], inst_i[5], inst_i[2], 5'd0, 2'b01, inst_i[9:7], 3'b000, inst_i[11], inst_i[10], inst_i[4], inst_i[3], inst_i[12], 7'b1100011 };
        5'b111_01: inst = { {4{inst_i[12]}}, inst_i[6], inst_i[5], inst_i[2], 5'd0, 2'b01, inst_i[9:7], 3'b001, inst_i[11], inst_i[10], inst_i[4], inst_i[3], inst_i[12], 7'b1100011 };
        5'b000_10: inst = { 7'b0000000, inst_i[6:2], inst_i[11:7], 3'b001, inst_i[11:7], 7'b0010011 };
        5'b010_10: inst = { 4'b0000, inst_i[3:2], inst_i[12], inst_i[6:4], 2'b0, 5'd2, 3'b010, inst_i[11:7], 7'b0000011 };
        5'b110_10: inst = { 4'b0000, inst_i[8:7], inst_i[12], inst_i[6:2], 5'd2, 3'b010, inst_i[11:9], 2'b00, 7'b0100011 };
        5'b100_10: begin
          case ({ inst_i[12], inst_i[6:2] != 5'b0 })
            2'b00: inst = { 12'b0, inst_i[11:7], 3'b000, 5'd0, 7'b1100111 };
            2'b10: inst = { 12'b0, inst_i[11:7], 3'b000, 5'd1, 7'b1100111 };
            2'b01: inst = { 7'b0, inst_i[6:2], 5'd0        , 3'b000, inst_i[11:7], 7'b0110011 };
            2'b11: inst = { 7'b0, inst_i[6:2], inst_i[11:7], 3'b000, inst_i[11:7], 7'b0110011 };
          endcase
        end
        default: inst = 32'bXXXXXXXX;
      endcase
    end else begin
      inst = inst_i;
    end
  end
endmodule
