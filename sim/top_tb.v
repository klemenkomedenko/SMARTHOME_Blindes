`timescale 1ns/1ps

module top_tb;

    // Parameters
    parameter CLK_PERIOD = 33.33333;

    // Signals
    reg i_clk;
    reg i_rst;
    wire [63:0] o_pwm;
    wire i_rx;
    wire o_tx;

    reg [7:0] i_tx_data;
    reg i_tx_start;
    wire [7:0] o_rx_data;
    wire o_rx_vld;
    wire o_tx_busy;

    // Instantiate the DUT (replace 'top' with your actual module name)
    top # (
        .g_CLK_FREQ(30_000_000),
        .g_BAUD_RATE(1_000_000),
        .g_BEAT_FREQ(100000)
    )
    top_inst (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rx(i_rx),
        .o_tx(o_tx),
        .o_pwm(o_pwm)
    );

    uart # (
    .g_CLK_FREQ(30_000_000),
    .g_BAUD_RATE(1_000_000)
    )
    uart_inst (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rx(o_tx),
        .o_tx(i_rx),
        .o_rx_data(o_rx_data),
        .o_rx_vld(o_rx_vld),
        .i_tx_data(i_tx_data),
        .i_tx_start(i_tx_start),
        .o_tx_busy(o_tx_busy)
    );

    // Clock generation
    initial i_clk = 0;
    always #(CLK_PERIOD/2) i_clk = ~i_clk;

    // Stimulus
    initial begin
        // Initialize inputs
        i_rst = 1;
        repeat (40) @(posedge i_clk);
        i_rst = 0;
        repeat (40) @(posedge i_clk);
        en_init(8'h45); // 'K'
        read_init();
        en_pwm(64'h00000000050000f1);
        repeat (200) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        inc_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        repeat (200) @(posedge i_clk);
        // $stop;        inc_pwm(64'h00000000050000f1);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
        repeat (1000000) @(posedge i_clk);
        dec_pwm(64'h00000000050000f1);
    end

    task automatic send_uart;
        input [7:0] data;
        begin
            @(posedge i_clk);
            i_tx_data = data;
            i_tx_start = 1;
            @(posedge i_clk);
            i_tx_start = 0;
            wait (o_tx_busy == 1);
            @(posedge i_clk);
            wait (o_tx_busy == 0);
        end
    endtask

    task automatic receive_uart;
        output [7:0] data;
        begin
            wait (o_rx_vld == 1);
            data = o_rx_data;
        end
    endtask

    task automatic en_pwm;
        input [63:0] en;
        begin
            send_uart(8'h4B);
            send_uart(8'h02);
            send_uart(8'h07);
            send_uart(en[7:0]);
            send_uart(en[15:8]);
            send_uart(en[23:16]);
            send_uart(en[31:24]);
            send_uart(en[39:32]);
            send_uart(en[47:40]);
            send_uart(en[55:48]);
            send_uart(en[63:56]);
            send_uart(8'h0D);
        end
    endtask

    task automatic inc_pwm;
        input [63:0] inc;
        begin
            send_uart(8'h4B);
            send_uart(8'h0A);
            send_uart(8'h07);
            send_uart(inc[7:0]);
            send_uart(inc[15:8]);
            send_uart(inc[23:16]);
            send_uart(inc[31:24]);
            send_uart(inc[39:32]);
            send_uart(inc[47:40]);
            send_uart(inc[55:48]);
            send_uart(inc[63:56]);
            send_uart(8'h0D);
        end
    endtask

    task automatic dec_pwm;
        input [63:0] dec;
        begin
            send_uart(8'h4B);
            send_uart(8'h12);
            send_uart(8'h07);
            send_uart(dec[7:0]);
            send_uart(dec[15:8]);
            send_uart(dec[23:16]);
            send_uart(dec[31:24]);
            send_uart(dec[39:32]);
            send_uart(dec[47:40]);
            send_uart(dec[55:48]);
            send_uart(dec[63:56]);
            send_uart(8'h0D);
        end
    endtask

    task automatic en_init;
        input [7:0] init_val;
        begin
            send_uart(8'h4B);
            send_uart(8'h00);
            send_uart(8'h00);
            send_uart(init_val);
            send_uart(8'h0D);
        end
    endtask

    task automatic read_init;
        begin
            send_uart(8'hB4);
            send_uart(8'h00);
            send_uart(8'h00);
            fatch_init(0); // Expecting 8 bytes of data
        end
    endtask


    reg [7:0] rx_uart_data;
    integer i;
    task automatic fatch_init;
        input [7:0] len;
        begin
            receive_uart(rx_uart_data);
            if (rx_uart_data == 8'h87) begin
                $display("Received ACK for read_init");
            end else begin
                $display("Expected ACK (0x87), but received: %h", rx_uart_data);
            end
            for (i = 0; i < len + 1; i = i + 1) begin
                receive_uart(rx_uart_data);
                $display("Recived data: %h", rx_uart_data);
            end
            receive_uart(rx_uart_data);
        end
    endtask
endmodule