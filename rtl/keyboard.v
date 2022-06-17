
module keyboard(
  input reset,
  input clk_sys,
  input [10:0] ps2_key,
  input [3:0] kb_col,
  output reg [3:0] kb_key,
  output reg [3:0] kb_mod,
  output reg status
);

reg [3:0] keys[15:0];

always @(posedge clk_sys) begin
  reg toggle;

  toggle <= ps2_key[10];
  if (toggle != ps2_key[10]) status <= ps2_key[9];

  kb_key <= keys[kb_col];

  if (reset) begin
    keys[0] <= 4'b1111;
    keys[1] <= 4'b1111;
    keys[2] <= 4'b1111;
    keys[3] <= 4'b1111;
    keys[4] <= 4'b1111;
    keys[5] <= 4'b1111;
    keys[6] <= 4'b1111;
    keys[7] <= 4'b1111;
    keys[8] <= 4'b1111;
    keys[9] <= 4'b1111;
    keys[10] <= 4'b1111;
    keys[11] <= 4'b1111;
    keys[12] <= 4'b1111;
    keys[13] <= 4'b1111;
    keys[14] <= 4'b1111;
    keys[15] <= 4'b1111;
    kb_mod <= 4'b1111;
  end
  else begin

    case (ps2_key[7:0])

      8'h12,
      8'h59: kb_mod <= { 2'b11, ~status, 1'b1 }; // shift

      8'h1a: keys[0][0] <= ~status; // z
      8'h1c: keys[0][1] <= ~status; // a
      8'h15: keys[0][2] <= ~status; // q
      8'h16: keys[0][3] <= ~status; // 1

      8'h22: keys[1][0] <= ~status; // x
      8'h1b: keys[1][1] <= ~status; // s
      8'h1d: keys[1][2] <= ~status; // w
      8'h1e:
        if (~kb_mod[1])
          keys[10][2] <= ~status;   // @
        else
          keys[1][3] <= ~status;    // 2

      8'h21: keys[2][0] <= ~status; // c
      8'h23: keys[2][1] <= ~status; // d
      8'h24: keys[2][2] <= ~status; // e
      8'h26: keys[2][3] <= ~status; // 3

      8'h2a: keys[3][0] <= ~status; // v
      8'h2b: keys[3][1] <= ~status; // f
      8'h2d: keys[3][2] <= ~status; // r
      8'h25: keys[3][3] <= ~status; // 4

      8'h32: keys[4][0] <= ~status; // b
      8'h34: keys[4][1] <= ~status; // g
      8'h2c: keys[4][2] <= ~status; // t
      8'h2e: keys[4][3] <= ~status; // 5

      8'h31: keys[5][0] <= ~status; // n
      8'h33: keys[5][1] <= ~status; // h
      8'h35: keys[5][2] <= ~status; // y
      8'h36:
        if (~kb_mod[1])
          keys[11][3] <= ~status;   // ^
        else
          keys[5][3] <= ~status;    // 6

      8'h3a: keys[6][0] <= ~status; // m
      8'h3b: keys[6][1] <= ~status; // j
      8'h3c: keys[6][2] <= ~status; // u
      8'h3d: keys[6][3] <= ~status; // 7

      8'h41: keys[7][0] <= ~status; // ,
      8'h42: keys[7][1] <= ~status; // k
      8'h43: keys[7][2] <= ~status; // i
      8'h3e: keys[7][3] <= ~status; // 8

      8'h49: keys[8][0] <= ~status; // .
      8'h4b: keys[8][1] <= ~status; // l
      8'h44: keys[8][2] <= ~status; // o
      8'h46: keys[8][3] <= ~status; // 9

      8'h4a: keys[9][0] <= ~status; // /

      8'h4c:
        if (~kb_mod[1])
          keys[10][1] <= ~status;   // :
        else
          keys[9][1] <= ~status;    // ;

      8'h4d: keys[9][2] <= ~status; // p
      8'h45: keys[9][3] <= ~status; // 0

      8'h2d:
        if (~kb_mod[1])
          keys[10][3] <= ~status;   // -
        else
          keys[10][0] <= ~status;   // _

      8'h29: keys[11][0] <= ~status; // space
      8'h5b: keys[11][1] <= ~status; // ]
      8'h54: keys[11][2] <= ~status; // [

      //8'h: keys[12][0] <= ~status; // nc?
      8'h5a: keys[12][1] <= ~status; // enter
      8'h66: keys[12][2] <= ~status; // backspace
      8'h5d: keys[12][3] <= ~status; // \

    endcase

  end

end

  // { 0, 0, 0, '!' },
  // { 0, 0, 0, '"' },
  // { 0, 0, 0, '#' },
  // { 0, 0, 0, '$' },
  // { 0, 0, 0, '%' },
  // { 0, 0, 0, '&' },
  // { 0, 0, 0, '\'' },
  // { '<', 0, 0, '(' },
  // { '>', 0, 0, ')' },
  // { '?', 0, 0, 0 },
  // { 0, '+', 0, '=' },
  // { 0, 0, 0, 0 },
  // { 0, 0, 0, 0 }

endmodule
