module top(
  input  logic        CLK100MHZ,
  input  logic        CPU_RESETN,

  output logic [15:0] LED,

  output logic        CA,
  output logic        CB,
  output logic        CC,
  output logic        CD,
  output logic        CE,
  output logic        CF,
  output logic        CG,
  output logic        DP,
  output logic [7:0]  AN,

  input  logic        ACL_MISO,
  output logic        ACL_MOSI,
  output logic        ACL_SCLK,
  output logic        ACL_CSN
);
  logic       clk_100mhz;
  logic       clk_8mhz;
  logic       nrst;

  logic [4:0] acl_x;
  logic [4:0] acl_y;
  logic [4:0] acl_z;

  pll PLL(
    .clk_in     (CLK100MHZ),
    .clk_100mhz (clk_100mhz),
    .clk_8mhz   (clk_8mhz)
  );

  acl ACL(
    .clk_8mhz (clk_8mhz),
    .nrst     (CPU_RESETN),
    .miso     (ACL_MISO),
    .mosi     (ACL_MOSI),
    .sclk     (ACL_SCLK),
    .csn      (ACL_CSN),
    .x        (acl_x),
    .y        (acl_y),
    .z        (acl_z)
  );

  /*
   * Seven-segment display handling
   */
  logic [3:0] ss_val;
  logic       ss_d;
  logic       ss_valid;
  logic [2:0] ss_can;

  seven_seg SEVEN_SEG(
    .clk_100mhz (clk_100mhz),
    .nrst       (CPU_RESETN),
    .ca         (CA),
    .cb         (CB),
    .cc         (CC),
    .cd         (CD),
    .ce         (CE),
    .cf         (CF),
    .cg         (CG),
    .dp         (DP),
    .an         (AN),
    .val        (ss_val),
    .d          (ss_d),
    .valid      (ss_valid),
    .can        (ss_can)
  );

  logic [3:0] x0;
  logic [3:0] x1;
  logic [3:0] y0;
  logic [3:0] y1;
  logic [3:0] z0;
  logic [3:0] z1;

  assign x0 = acl_x[3:0] < 10 ? acl_x[3:0] : acl_x[3:0] - 10;
  assign x1 = acl_x[3:0] >= 10;

  assign y0 = acl_y[3:0] < 10 ? acl_y[3:0] : acl_y[3:0] - 10;
  assign y1 = acl_y[3:0] >= 10;

  assign z0 = acl_z[3:0] < 10 ? acl_z[3:0] : acl_z[3:0] - 10;
  assign z1 = acl_z[3:0] >= 10;

  always_comb begin
    ss_val   = 'bx;
    ss_d     = 'bx;
    ss_valid = 0;

    case (ss_can)
      0: begin
        ss_val   = z0;
        ss_d     = acl_z[4];
        ss_valid = 1;
      end

      1: begin
        ss_val   = z1;
        ss_d     = 0;
        ss_valid = 1;
      end

      3: begin
        ss_val   = y0;
        ss_d     = acl_y[4];
        ss_valid = 1;
      end

      4: begin
        ss_val   = y1;
        ss_d     = 0;
        ss_valid = 1;
      end

      6: begin
        ss_val   = x0;
        ss_d     = acl_x[4];
        ss_valid = 1;
      end

      7: begin
        ss_val   = x1;
        ss_d     = 0;
        ss_valid = 1;
      end
    endcase
  end
endmodule
