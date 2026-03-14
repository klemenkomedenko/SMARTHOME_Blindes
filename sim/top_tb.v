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

    integer blind_1 = 0;
    integer blind_2 = 5;
    integer blind_3 = 10;
    integer blind_4 = 15;
    integer blind_5 = 20;
    integer blind_6 = 25;
    integer blind_7 = 30;
    integer blind_8 = 35;
    integer blind_9 = 40;
    integer blind_10 = 45;

    // Instantiate the DUT (replace 'top' with your actual module name)
    top # (
    .g_CLK_FREQ(30_000_000),
    .g_BAUD_RATE(1_000_000),
    .g_BEAT_FREQ(1_000),
    .g_N_BLINDS(11),
    .g_N_ON_OFF(5),
    .g_timer(100),
    .g_dly_timer(50)
    )
    top_inst (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rx(i_rx),
        .o_tx(o_tx),
        .o_relay_up(),
        .o_relay_down(),
        .o_on_off()
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
        send_en_init_timer(blind_1, 16'h0045);
        send_en_init_timer(blind_2, 16'h0045);
        send_en_init_timer(blind_3, 16'h0045);
        send_en_init_timer(blind_4, 16'h0045);
        send_en_init_timer(blind_5, 16'h0045);
        send_en_init_timer(blind_6, 16'h0045);
        send_en_init_timer(blind_7, 16'h0045);
        send_en_init_timer(blind_8, 16'h0045);
        send_en_init_timer(blind_9, 16'h0045);
        send_en_init_timer(blind_10, 16'h0045);

        repeat (11459075) @(posedge i_clk);
        up_on(blind_1);
        up_on(blind_2);
        repeat (200) @(posedge i_clk);
        up_off(blind_1);
        up_off(blind_2);
        
        repeat (11459075) @(posedge i_clk);
        down_on(blind_1);
        down_on(blind_2);
        repeat (200) @(posedge i_clk);
        down_off(blind_1);
        down_off(blind_2);
        
        repeat (11459075) @(posedge i_clk);
        up_on(blind_1);
        up_on(blind_2);
        repeat (2082620) @(posedge i_clk);
        up_off(blind_1);        
        up_off(blind_2);        
        
        repeat (11459075) @(posedge i_clk);
        down_on(blind_1);
        down_on(blind_2);
        repeat (2082620) @(posedge i_clk);
        down_off(blind_1);
        down_off(blind_2);

        // Test user command while opening to stop in the middle
        repeat (11459075) @(posedge i_clk);
        up_on(blind_1);
        up_on(blind_2);
        repeat (200) @(posedge i_clk);
        up_off(blind_1);
        up_off(blind_2);

        repeat (2246114) @(posedge i_clk);
        up_on(blind_1);
        up_on(blind_2);
        repeat (200) @(posedge i_clk);
        up_off(blind_1);
        up_off(blind_2);

        // Test user command while opening to stop in the middle
        repeat (11459075) @(posedge i_clk);
        down_on(blind_1);
        down_on(blind_2);
        repeat (200) @(posedge i_clk);
        down_off(blind_1);
        down_off(blind_2);

        repeat (2246114) @(posedge i_clk);
        down_on(blind_1);
        down_on(blind_2);
        repeat (200) @(posedge i_clk);
        down_off(blind_1);
        down_off(blind_2);

        relay_on(55);
        repeat (2246114) @(posedge i_clk);
        relay_off(55);
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

    task automatic send_en_init_timer;
        input [7:0] addr;
        input [15:0] timer;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr);   // Command byte
            send_uart(8'h02);   // Command byte
            send_uart(timer[7:0]); // Length byte (0 for commands without parameters)
            send_uart(timer[15:8]); // End byte
            send_uart(8'h01); 
            send_uart(8'h0D);// End byte
        end
    endtask

    task automatic send_dis_init_timer;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr);   // Command byte
            send_uart(8'h00); // End byte
            send_uart(8'h0D);
        end
    endtask

    task automatic up_on;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr+3);   // Command byte
            send_uart(8'h00);   // Command byte
            send_uart(8'h01); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask

    task automatic up_off;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr+3);   // Command byte
            send_uart(8'h00);   // Command byte
            send_uart(8'h00); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask

    task automatic down_on;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr+4);   // Command byte
            send_uart(8'h00);   // Command byte
            send_uart(8'h01); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask

    task automatic down_off;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr+4);   // Command byte
            send_uart(8'h00);   // Command byte
            send_uart(8'h00); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask



    task automatic on_on;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr);   // Command byte
            send_uart(8'h00);   // Command byte
            send_uart(8'h01); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask


    task automatic on_off;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr);   // Command byte
            send_uart(8'h00);   // Command byte
            send_uart(8'h01); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask



    task automatic relay_on;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr);   // Command byte
            send_uart(8'h00);   // Length byte (0 for commands without parameters)
            send_uart(8'h01); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
        end
    endtask

    task automatic relay_off;
        input [7:0] addr;
        begin
            send_uart(8'h4B); // Start byte
            send_uart(addr);   // Command byte
            send_uart(8'h00);   // Length byte (0 for commands without parameters)
            send_uart(8'h01); // Length byte (0 for commands without parameters)
            send_uart(8'h0D);// End byte
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