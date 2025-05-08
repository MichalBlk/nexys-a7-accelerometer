module acl(
  input  logic       clk_8mhz,
  input  logic       nrst,

  input  logic       miso,
  output logic       mosi,
  output logic       sclk,
  output logic       csn,

  output logic [4:0] x,
  output logic [4:0] y,
  output logic [4:0] z
);
  localparam TICK            = 8;
  localparam MS              = 8000;

  localparam CMD_WRITE       = 8'h0a;
  localparam CMD_READ        = 8'h0b;

  localparam REG_POWER_CTL   = 8'h2d;
  localparam REG_XDATA_L     = 8'h0e;

  localparam POWER_CTL_MMODE = 8'h02;

  typedef enum logic [3:0] {
    ST_INIT_WAIT,
    ST_EN_CS,
    ST_EN_CMD,
    ST_EN_ADDR,
    ST_EN_DATA,
    ST_EN_WAIT,
    ST_M_CS,
    ST_M_CMD,
    ST_M_ADDR,
    ST_XL_DATA,
    ST_XH_DATA,
    ST_YL_DATA,
    ST_YH_DATA,
    ST_ZL_DATA,
    ST_ZH_DATA,
    ST_M_WAIT
  } state_t;

  state_t      state, state_r;
  logic [29:0] cnt, cnt_r;
  logic [2:0]  clk_cnt, clk_cnt_r;
  logic [15:0] x_data, x_data_r;
  logic [15:0] y_data, y_data_r;
  logic [15:0] z_data, z_data_r;
  logic [4:0]  x_out, x_out_r;
  logic [4:0]  y_out, y_out_r;
  logic [4:0]  z_out, z_out_r;
  logic [7:0]  wshr, wshr_r;
  logic [7:0]  rshr, rshr_r;
  logic        sclk_en, sclk_en_r;
  logic        cs, cs_r;
  logic        clk_1mhz;

  /*
   * Clock counter
   */
  assign clk_cnt = clk_cnt_r + 1;

  always_ff @(posedge clk_8mhz, negedge nrst)
    if (!nrst)
      clk_cnt_r <= 3'b100;
    else
      clk_cnt_r <= clk_cnt;

  assign clk_1mhz = clk_cnt_r[2];

  /*
   * Chip select handling
   */
  always_comb begin
    cs = cs_r;

    case (state_r)
      ST_EN_CS:
        if (!cnt_r)
          cs = 1;

      ST_EN_DATA:
        if (cnt_r == 8 * TICK - 1)
          cs = 0;

      ST_M_CS:
        if (!cnt_r)
          cs = 1;

      ST_ZH_DATA:
        if (cnt_r == 8 * TICK - 1)
          cs = 0;
    endcase
  end

  always_ff @(posedge clk_8mhz, negedge nrst)
    if (!nrst)
      cs_r <= 0;
    else
      cs_r <= cs;

  /*
   * Slave clock handling
   */
  always_comb begin
    sclk_en = sclk_en_r;

    case (state_r)
      ST_EN_CS:
        if (cnt_r == TICK - 1)
          sclk_en = 1;

      ST_EN_DATA:
        if (cnt_r == 8 * TICK - 1)
          sclk_en = 0;

      ST_M_CS:
        if (cnt_r == TICK - 1)
          sclk_en = 1;

      ST_ZH_DATA:
        if (cnt_r == 8 * TICK - 1)
          sclk_en = 0;
    endcase
  end

  always_ff @(posedge clk_8mhz, negedge nrst)
    if (!nrst)
      sclk_en_r <= 0;
    else
      sclk_en_r <= sclk_en;

  /*
   * Serial output
   */
  always_comb begin
    wshr = wshr_r;

    if ((cnt_r & 3'b111) == 3'b011)
      wshr = wshr_r << 1;

    case (state_r)
      ST_EN_CS:
        wshr = CMD_WRITE;

      ST_EN_CMD:
        if (cnt_r == 8 * TICK - 5)
          wshr = REG_POWER_CTL;

      ST_EN_ADDR:
        if (cnt_r == 8 * TICK - 5)
          wshr = POWER_CTL_MMODE;

      ST_M_CS:
        wshr = CMD_READ;

      ST_M_CMD:
        if (cnt_r == 8 * TICK - 5)
          wshr = REG_XDATA_L;
    endcase
  end

  always_ff @(posedge clk_8mhz)
    wshr_r <= wshr;

  /*
   * Serial input
   */
  assign rshr = cnt_r[2:0] == 3'b000 ? {rshr_r[6:0], miso} : rshr_r;

  always_ff @(posedge clk_8mhz)
    rshr_r <= rshr;

  always_comb begin
    x_data = x_data_r;
    y_data = y_data_r;
    z_data = z_data_r;

    case (state_r)
      ST_XH_DATA:
        if (!cnt_r)
          x_data[7:0] = rshr_r;

      ST_YL_DATA:
        if (!cnt_r)
          x_data[15:8] = rshr_r;

      ST_YH_DATA:
        if (!cnt_r)
          y_data[7:0] = rshr_r;

      ST_ZL_DATA:
        if (!cnt_r)
          y_data[15:8] = rshr_r;

      ST_ZH_DATA:
        if (!cnt_r)
          z_data[7:0] = rshr_r;

      ST_M_WAIT:
        if (!cnt_r)
          z_data[15:8] = rshr_r;
    endcase
  end

  always_ff @(posedge clk_8mhz) begin
    x_data_r <= x_data;
    y_data_r <= y_data;
    z_data_r <= z_data;
  end

  always_comb begin
    x_out = x_out_r;
    y_out = y_out_r;
    z_out = z_out_r;

    if (state_r == ST_M_WAIT && cnt_r) begin
      x_out = x_data_r[11:7];
      y_out = y_data_r[11:7];
      z_out = z_data_r[11:7];
    end
  end

  always_ff @(posedge clk_8mhz, negedge nrst)
    if (!nrst) begin
      x_out_r <= 0;
      y_out_r <= 0;
      z_out_r <= 0;
    end else begin
      x_out_r <= x_out;
      y_out_r <= y_out;
      z_out_r <= z_out;
    end

  /*
   * State and counter handling
   */ 
  always_comb begin
    state = state_r;
    cnt   = cnt_r + 1;

    case (state_r)
      ST_INIT_WAIT:
        if (cnt_r == 6 * MS - 1) begin
          state = ST_EN_CS;
          cnt   = 0;
        end

      ST_EN_CS:
        if (cnt_r == TICK - 1) begin
          state = ST_EN_CMD;
          cnt   = 0;
        end

      ST_EN_WAIT:
        if (cnt_r == 40 * MS - 1) begin
          state = ST_M_CS;
          cnt   = 0;
        end

      ST_M_CS:
        if (cnt_r == TICK - 1) begin
          state = ST_M_CMD;
          cnt   = 0;
        end

      ST_M_WAIT:
        if (cnt_r == 10 * MS - 1) begin
          state = ST_M_CS;
          cnt   = 0;
        end

      default:
        if (cnt_r == 8 * TICK - 1) begin
          state = state_t'(state_r + 1);
          cnt   = 0;
        end
    endcase
  end

  always_ff @(posedge clk_8mhz, negedge nrst)
    if (!nrst) begin
      state_r <= ST_INIT_WAIT;
      cnt_r   <= 0;
    end else begin
      state_r <= state;
      cnt_r   <= cnt;
    end

  /*
   * SPI output signals
   */
  assign mosi = wshr_r[7];
  assign sclk = sclk_en_r ? clk_1mhz : 0;
  assign csn  = !cs_r;

  /*
   * Other output signals
   */
  assign x = x_out_r;
  assign y = y_out_r;
  assign z = z_out_r;
endmodule
