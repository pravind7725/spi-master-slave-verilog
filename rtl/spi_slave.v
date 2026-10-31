module spi_slave #(
  parameter DATA_W = 8
)(
  input                   clk, rst_n,
  input                   cpol, cpha,
  input                   sclk, cs_n, mosi,
  output reg              miso,
  input  [DATA_W-1:0]     tx_data,     // jo slave master ko bhejega
  output reg [DATA_W-1:0] rx_data,
  output reg              rx_valid
);
  reg [2:0] sclk_q, cs_q, mosi_q;
  reg [7:0] bit_cnt;
  reg [DATA_W-1:0] tx_sh, rx_sh;

  wire rise = sclk_q[1] & ~sclk_q[2];
  wire fall = ~sclk_q[1] & sclk_q[2];
  wire leading  = cpol ? fall : rise;
  wire trailing = cpol ? rise : fall;
  wire sample_edge = cpha ? trailing : leading;
  wire shift_edge  = cpha ? leading  : trailing;

  wire cs_start  = cs_q[2] & ~cs_q[1];
  wire cs_active = ~cs_q[1];
  wire [DATA_W-1:0] rx_next = {rx_sh[DATA_W-2:0], mosi_q[1]};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_q <= 0; cs_q <= 3'b111; mosi_q <= 0;
      bit_cnt <= 0; tx_sh <= 0; rx_sh <= 0;
      miso <= 0; rx_data <= 0; rx_valid <= 0;
    end else begin
      sclk_q <= {sclk_q[1:0], sclk};
      cs_q   <= {cs_q[1:0],   cs_n};
      mosi_q <= {mosi_q[1:0], mosi};
      rx_valid <= 0;

      if (cs_start) begin
        tx_sh <= tx_data; bit_cnt <= 0;
        if (!cpha) miso <= tx_data[DATA_W-1];
      end else if (cs_active) begin
        if (sample_edge) begin
          rx_sh   <= rx_next;
          bit_cnt <= bit_cnt + 1;
          if (bit_cnt == DATA_W-1) begin
            rx_data <= rx_next; rx_valid <= 1;
          end
        end
        if (shift_edge && bit_cnt < DATA_W)
          miso <= tx_sh[DATA_W-1-bit_cnt];
      end
    end
  end
endmodule