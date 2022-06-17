
module video(
  input clk,

  output reg hs,
  output reg vs,
  output reg hb,
  output reg vb,

  output reg [8:0] hcount,
  output reg [8:0] vcount,

  output reg [7:0] red,
  output reg [7:0] green,
  output reg [7:0] blue,

  output reg [15:0] ram_addr,
  output reg [10:0] char_addr,
  input [7:0] ram_data,
  input [7:0] char_data,

  output reg frame,
  output reg ce_pix,

  input color_board,
  input inverted,

  input [7:0] charcolor,
  input [9:0] color_ram_addr,
  input color_ram_wr

);

// 256x192

initial begin
  hs = 1'b1;
  vs = 1'b1;
end


reg [7:0] color;
reg [7:0] color_ram[32*24:0];
wire [2:0] fg = inverted ? color[6:4] : color[2:0];
wire [2:0] bg = inverted ? color[2:0] : color[6:4];

always @(posedge clk) begin
  color <= color_ram[ram_addr-16'h100];
  if (color_ram_wr) color_ram[color_ram_addr] <= charcolor;
end

reg [1:0] state;
reg [7:0] px, py;
reg [2:0] vram[256*192:0];

always @(posedge clk) begin
  case (state)
    2'd0: begin
      ram_addr <= 16'h100 + (py/8) * 32 + (px/8);
      state <= 2'd1;
    end
    2'd1: begin
      char_addr <= { ram_data, py[2:0] };
      state <= 2'd2;
    end
    2'd2: begin

      if (color_board) begin
        vram[py*256+px] <= char_data[3'd7-px[2:0]] ? fg : bg;
      end
      else begin
        vram[py*256+px] <= char_data[3'd7-px[2:0]] ?
          inverted ? 3'b000 : 3'b111 :
          inverted ? 3'b111 : 3'b000;
      end

      px <= px + 8'd1;
      if (px == 255) begin
        py <= py + 8'd1;
        if (py == 8'd191) py <= 8'd0;
      end
      state <= 2'd0;
    end
  endcase
end

reg [15:0] vram_addr;
reg [2:0] vram_data;
always @(posedge clk) begin

  frame <= 1'b0;
  ce_pix <= ~ce_pix;

  if (~ce_pix) begin

    vram_addr <= vcount * 256 + hcount;
    vram_data <= vram[vram_addr];

  end

  else begin

    if (~(hb|vb)) begin
      red <= vram_data[2] ? 8'hff : 8'd0;
      green <= vram_data[1] ? 8'hff : 8'd0;
      blue <= vram_data[0] ? 8'hff : 8'd0;
    end

    hcount <= hcount + 9'd1;
    case (hcount)
      255: hb <= 1'b1;
      271: hs <= 1'b0;
      311: hs <= 1'b1;
      343: begin
        vcount <= vcount + 9'd1;
        hcount <= 9'b0;
        hb <= 1'b0;
        case (vcount)
          191: vb <= 1'b1;
          215: vs <= 1'b0;
          249: vs <= 1'b1;
          261: begin
            vcount <= 9'd0;
            vb <= 1'b0;
            frame <= 1'b1;
          end
        endcase
      end
    endcase

  end

end

endmodule