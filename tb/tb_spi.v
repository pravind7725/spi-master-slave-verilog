`timescale 1ns/1ps
module tb_spi;
  parameter N = 8;
  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  reg start = 0, cpol = 0, cpha = 0;
  reg [N-1:0] m_tx, s_tx;
  wire sclk, mosi, miso, cs_n, busy, done, s_valid;
  wire [N-1:0] m_rx, s_rx;

  spi_master #(.DATA_W(N), .CLK_DIV(8)) m (
    .clk(clk), .rst_n(rst_n), .start(start), .cpol(cpol), .cpha(cpha),
    .tx_data(m_tx), .miso(miso), .sclk(sclk), .mosi(mosi), .cs_n(cs_n),
    .rx_data(m_rx), .busy(busy), .done(done));

  spi_slave #(.DATA_W(N)) s (
    .clk(clk), .rst_n(rst_n), .cpol(cpol), .cpha(cpha),
    .sclk(sclk), .cs_n(cs_n), .mosi(mosi), .miso(miso),
    .tx_data(s_tx), .rx_data(s_rx), .rx_valid(s_valid));

  integer mode, i, errors = 0;

  task xfer(input [N-1:0] a, input [N-1:0] b);
    begin
      m_tx = a; s_tx = b;
      @(posedge clk); start <= 1;
      @(posedge clk); start <= 0;
      @(posedge done);
      repeat (10) @(posedge clk);
      if (s_rx !== a || m_rx !== b) begin
        errors = errors + 1;
        $display("FAIL mode %0d: M->S %h/%h  S->M %h/%h", mode, a, s_rx, b, m_rx);
      end
    end
  endtask

  initial begin
    $dumpfile("spi.vcd"); $dumpvars(0, tb_spi);
    repeat (4) @(posedge clk); rst_n = 1; repeat (4) @(posedge clk);
    for (mode = 0; mode < 4; mode = mode + 1) begin
      {cpol, cpha} = mode[1:0];
      repeat (3) @(posedge clk);
      xfer(8'h00, 8'hFF); xfer(8'hFF, 8'h00); xfer(8'hA5, 8'h5A);
      for (i = 0; i < 50; i = i + 1) xfer($random, $random);
    end
    if (errors == 0) $display("ALL TESTS PASSED");
    else             $display("%0d ERRORS", errors);
    $finish;
  end
endmodule