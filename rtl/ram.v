
module ram(
  input clk,
  input [15:0] addr,
  input [7:0] din,
  output [7:0] dout,
  input wr,
  input ce,

  input [15:0] addr_b,
  output [7:0] dout_b
);

dpram dpram(
  .address_a(addr),
  .address_b(addr_b),
  .clock(clk),
  .data_a(din),
  .data_b(),
  .rden_a(ce),
  .rden_b(1'b1),
  .wren_a(wr),
  .wren_b(1'b0),
  .q_a(dout),
  .q_b(dout_b)
);

endmodule
