
module rom #(parameter MEMFILE="", DW=8, AW=16)
(
  input clk,
  input [AW-1:0] addr,
  output [DW-1:0] dout,
  input ce
);

reg [DW-1:0] q;
reg [DW-1:0] mem[(1<<AW)-1:0];

assign dout = ce ? q : {DW{1'b0}};

initial begin
  $readmemh(MEMFILE, mem);
end

always @(posedge clk)
  q <= mem[addr];

endmodule
