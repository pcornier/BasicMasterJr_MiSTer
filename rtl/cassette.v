// cassette.v - Kansas City Standard tape decoder
// Reads CAS data from SDRAM, decodes KCS audio, outputs bit to CPU

module cassette(
  input clk_sys,
  input reset,

  input tape_start,

  // SDRAM interface (active-edge rd/we, 16-bit data)
  output reg [24:0] sdram_addr,
  input [15:0] sdram_data,
  output reg sdram_rd,
  output reg sdram_we,
  output reg [1:0] sdram_wtbt,
  input sdram_ready,

  output wire tape_bit,
  output wire tape_bit_stable_out,
  output [2:0] status
);

  // CAS format: 9600 Hz sample rate, 8-bit unsigned (KCS standard)
  localparam TICKS_PER_SAMPLE = 32'd5000;  // 48MHz / 9600Hz
  localparam CAS_HEADER_SIZE  = 9'd380;    // Header size in bytes (0x7F leader)

  localparam KC_ONE_THRESHOLD = 32'd14400;  // < 300 us between transitions = "1" bit
  localparam KC_TIMEOUT       = 32'd38400;  // > 800 us no transition = timeout, bit = "0"

  // SDRAM reader state machine
  localparam
    S_SKIP_HEADER = 3'd0,
    S_PLAY_WAIT   = 3'd1,
    S_FETCH_DATA  = 3'd2;

  reg [2:0] state;
  reg [31:0] timer;
  reg [8:0] header_counter;
  reg tape_start_prev;

  // Audio threshold bit (raw from SDRAM sample)
  reg tape_bit_raw;

  // Kansas City decoder
  reg [31:0] kc_counter;
  reg kc_prev;
  reg kc_bit;

  // SDRAM read edge detection
  reg sdram_rd_prev;

  assign status = state;
  assign tape_bit = tape_bit_raw;
  assign tape_bit_stable_out = kc_bit;

  // SDRAM reader: reads samples at 9600 Hz, converts to raw bit
  always @(posedge clk_sys) begin
    tape_start_prev <= tape_start;
    sdram_rd_prev <= sdram_rd;

    if (reset) begin
      state <= S_SKIP_HEADER;
      sdram_addr <= 25'd0;
      sdram_rd <= 1'b0;
      sdram_we <= 1'b0;
      sdram_wtbt <= 2'b00;
      tape_bit_raw <= 1'b0;
      timer <= 32'd0;
      header_counter <= 9'd0;
      tape_start_prev <= 1'b0;
    end else begin
      // Default: clear rd/we pulses
      if (sdram_rd_prev) sdram_rd <= 1'b0;

      if (tape_start && !tape_start_prev) begin
        sdram_addr <= 25'd0;
        state <= S_SKIP_HEADER;
        timer <= 32'd0;
        header_counter <= 9'd0;
        sdram_rd <= 1'b0;
      end else if (tape_start) begin
        case (state)
          S_SKIP_HEADER: begin
            if (sdram_ready && !sdram_rd) begin
              sdram_rd <= 1'b1;
            end
            if (sdram_ready && sdram_rd) begin
              if (header_counter < CAS_HEADER_SIZE) begin
                header_counter <= header_counter + 9'd1;
                sdram_addr <= sdram_addr + 25'd1;
                sdram_rd <= 1'b0;
              end else begin
                state <= S_PLAY_WAIT;
                timer <= 32'd0;
              end
            end
          end

          S_PLAY_WAIT: begin
            sdram_rd <= 1'b0;
            if (timer >= TICKS_PER_SAMPLE) begin
              timer <= 32'd0;
              state <= S_FETCH_DATA;
            end else begin
              timer <= timer + 32'd1;
            end
          end

          S_FETCH_DATA: begin
            if (sdram_ready && !sdram_rd) begin
              sdram_rd <= 1'b1;
            end
            if (sdram_ready && sdram_rd) begin
              // SDRAM is 16-bit, select byte based on addr[0]
              tape_bit_raw <= (sdram_data[7:0] > 8'h80) ? 1'b1 : 1'b0;
              sdram_addr <= sdram_addr + 25'd1;
              sdram_rd <= 1'b0;
              state <= S_PLAY_WAIT;
            end
          end

          default: state <= S_SKIP_HEADER;
        endcase
      end else begin
        sdram_rd <= 1'b0;
      end
    end
  end

  // Kansas City standard decoder
  always @(posedge clk_sys) begin
    if (reset) begin
      kc_counter <= 32'd0;
      kc_prev <= 1'b0;
      kc_bit <= 1'b0;
    end else begin
      kc_prev <= tape_bit_raw;

      if (tape_bit_raw != kc_prev) begin
        kc_bit <= (kc_counter < KC_ONE_THRESHOLD) ? 1'b1 : 1'b0;
        kc_counter <= 32'd0;
      end else begin
        kc_counter <= kc_counter + 32'd1;
        if (kc_counter > KC_TIMEOUT) begin
          kc_counter <= KC_TIMEOUT;
          kc_bit <= 1'b0;
        end
      end
    end
  end

endmodule
