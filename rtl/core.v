
module core(
  input reset,

  input clk_sys,
  input clk_cpu,
  input clk_vid,

  output reg [7:0] kb_col,
  input [3:0] kb_key,
  input [3:0] kb_mod,
  input key_pressed,

  output hs,
  output vs,
  output hb,
  output vb,
  output ce_pix,
  output [7:0] red,
  output [7:0] green,
  output [7:0] blue,

  input tape_bit,
  output reg tape_start,
  output reg tape_stop

);

wire [15:0] cpu_addr;
wire [7:0] cpu_dout;
wire cpu_rw;

wire [7:0] mux_out;
wire [7:0] mux = ~mux_out;

reg [7:0] io_out;
wire [7:0] ram_dout;
wire [7:0] rom0_dout, romB_dout, romDF_dout, romE_dout;
wire [7:0] rom_dout = romB_dout | romDF_dout | romE_dout;

wire romB_sel = cpu_rw & ~bank[0] & (mux[3]|mux[4]);
wire romD_sel = cpu_rw & ~bank[0] & mux[5];
wire romE_sel = cpu_rw & ~bank[1] & mux[6] & ~cpu_addr[11];
wire romF_sel = cpu_rw & ~bank[2] & mux[7];

wire rom_sel = romB_sel | romD_sel | romE_sel | romF_sel;
wire ram_sel = ~rom_sel;
wire io_sel = mux[6] & cpu_addr[11];

wire [7:0] cpu_din =
  io_sel ? io_out :
  rom_sel ? rom_dout :
  ram_sel ? ram_dout : 8'hff;

wire vram_write = cpu_addr >= 16'h100 && cpu_addr < 16'h400;

wire [15:0] video_ram_addr;
wire [7:0] video_ram_data;
wire [10:0] video_char_addr;

video video(
  .clk(clk_vid),
  .hs(hs),
  .vs(vs),
  .hb(hb),
  .vb(vb),
  .red(red),
  .green(green),
  .blue(blue),
  .ce_pix(ce_pix),
  .ram_addr(video_ram_addr),
  .char_addr(video_char_addr),
  .ram_data(video_ram_data),
  .char_data(rom0_dout),
  .color_board(color_board),
  .inverted(xor_disp[7]),
  .charcolor(charcolor[0]),
  .color_ram_addr(cpu_addr - 16'h100),
  .color_ram_wr(vram_write)
);

reg [3:0] icyc;
reg irq;
reg old_vs;
always @(posedge clk_cpu) begin
  old_vs <= vs;
  if (old_vs & ~vs) begin
    irq <= 1'b1;
  end
  if (irq) begin
    icyc <= icyc + 4'd1;
    if (icyc == 4'd10) begin
      icyc <= 4'd0;
      irq <= 1'b0;
    end
  end
end

m6801 cpu(
  .clk(clk_cpu),
  .rst(reset),
  .cen(1'b1),
  .rw(cpu_rw),
  .vma(vma),
  .address(cpu_addr),
  .data_in(cpu_din),
  .data_out(cpu_dout),
  .halt(1'b0),
  .halted(),
  .irq(),
  .nmi(),
  .irq_icf(),
  .irq_ocf(),
  .irq_tof(),
  .irq_sci()
);

// rom mux
x74138 rom_mux(
  .G1(cpu_addr[15]),
  .G2A(1'b0),
  .G2B(1'b0),
  .A(cpu_addr[14:12]),
  .Y(mux_out)
);

ram ram(
  .clk(clk_sys),
  .addr(cpu_addr),
  .din(cpu_dout),
  .dout(ram_dout),
  .wr(~cpu_rw),
  .ce(ram_sel),
  .addr_b(video_ram_addr),
  .dout_b(video_ram_data)
);

// read by video
rom #(.MEMFILE("rom0.mem"), .DW(8), .AW(11)) rom0(
  .clk(clk_sys),
  .addr(video_char_addr),
  .dout(rom0_dout),
  .ce(1'b1)
);

rom #(.MEMFILE("romb.mem"), .DW(8), .AW(13)) romB(clk_sys, { ~cpu_addr[12], cpu_addr[11:0] }, romB_dout, romB_sel);
rom #(.MEMFILE("romdf.mem"), .DW(8), .AW(13)) romDF(clk_sys, { cpu_addr[13], cpu_addr[11:0] }, romDF_dout, romD_sel|romF_sel);
rom #(.MEMFILE("rome.mem"), .DW(8), .AW(11)) romE(clk_sys, cpu_addr[10:0], romE_dout);


// IO map
reg [7:0] xor_disp;
reg [7:0] charcolor;
reg [7:0] color_board;
reg [2:0] bank;
reg timer_en;
reg kb_nmi_en;
wire dbg_tape_read = cpu_addr == 16'hee80;

always @(posedge clk_sys) begin
  io_out <= 8'hff;
  tape_start <= 1'b0;
  tape_stop <= 1'b0;
  if (reset) begin
    charcolor <= 8'b0000_0111;
    xor_disp <= 8'd0;
  end
  else if (io_sel) begin
    case (cpu_addr)
      16'he890: begin
        if (cpu_rw)
          io_out <= charcolor;
        else
          charcolor <= cpu_dout;
      end
      16'he892: begin
        if (cpu_rw)
          io_out <= color_board;
        else
          color_board <= cpu_dout;
      end
      16'hee00: begin
        io_out <= 1'b1;
        tape_stop <= 1'b1;
      end
      16'hee20: begin
        io_out <= 1'b1;
        tape_start <= 1'b1;
      end
      16'hee40: xor_disp <= cpu_dout;
      16'hee80: // tape read/write
        if (cpu_rw)
          io_out <= { tape_bit, 7'd0 };
        // else write;
      16'heec0: begin // kb
        if (cpu_rw)
          io_out <= { kb_mod, kb_key };
        else
          { kb_nmi_en, kb_col[6:0] } <= cpu_dout;
      end
      16'hef00: io_out <= 8'hff; //counter; // counter
      16'hef80: io_out <= 8'h00; // break key?
      16'hefd0: // ic8[15:12] 1110 ic6[11:6] 111 111 [5] 0 ic13[4:0] 10000
        if (cpu_rw)
          { timer_en, bank } <= { cpu_dout[4], cpu_dout[2:0] };
        else
          io_out <= bank;
      16'hefe0: ; // screen mode
      default: io_out <= 8'hff;
    endcase
  end
end

endmodule
