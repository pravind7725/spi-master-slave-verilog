module spi_master #(
  parameter DATA_W  = 8,
  parameter CLK_DIV = 8      // SCLK half-period = CLK_DIV system clocks
)(
  input                   clk, rst_n,
  input                   start,
  input                   cpol, cpha,
  input  [DATA_W-1:0]     tx_data,
  input                   miso,
  output reg              sclk, mosi, cs_n,
  output reg [DATA_W-1:0] rx_data,
  output reg              busy, done
);
  localparam IDLE = 2'd0, RUN = 2'd1, TAIL = 2'd2;
  reg [1:0]        state;
  reg [15:0]       div_cnt;
  reg [7:0]        edge_cnt;
  reg [DATA_W-1:0] tx_reg, rx_sh;

  wire [7:0]        bit_idx   = edge_cnt >> 1;
  wire [DATA_W-1:0] rx_next   = {rx_sh[DATA_W-2:0], miso};
  wire              last_edge = (edge_cnt == 2*DATA_W-1);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE; sclk <= 0; mosi <= 0; cs_n <= 1;
      busy <= 0; done <= 0; rx_data <= 0; rx_sh <= 0;
      div_cnt <= 0; edge_cnt <= 0; tx_reg <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          sclk <= cpol;
          if (start) begin
            tx_reg <= tx_data; cs_n <= 0; busy <= 1;
            div_cnt <= 0; edge_cnt <= 0; state <= RUN;
            if (!cpha) mosi <= tx_data[DATA_W-1];  // first bit pehle se ready
          end
        end

        RUN: begin
          if (div_cnt == CLK_DIV-1) begin
            div_cnt  <= 0;
            sclk     <= ~sclk;
            edge_cnt <= edge_cnt + 1;
            if (!edge_cnt[0]) begin                 // leading edge
              if (!cpha) rx_sh <= rx_next;          // sample
              else       mosi  <= tx_reg[DATA_W-1-bit_idx];  // shift
            end else begin                          // trailing edge
              if (cpha)  rx_sh <= rx_next;          // sample
              else if (!last_edge)
                         mosi  <= tx_reg[DATA_W-2-bit_idx];  // shift
            end
            if (last_edge) begin
              rx_data <= cpha ? rx_next : rx_sh;
              state   <= TAIL; div_cnt <= 0;
            end
          end else div_cnt <= div_cnt + 1;
        end

        TAIL: begin   // CS ko aadha period extra low rakho
          if (div_cnt == CLK_DIV-1) begin
            cs_n <= 1; busy <= 0; done <= 1; state <= IDLE;
          end else div_cnt <= div_cnt + 1;
        end
      endcase
    end
  end
endmodule