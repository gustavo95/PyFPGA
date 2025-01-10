`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UFRN
// Engineer: Gustavo Costa Gomes de Melo
// 
// Create Date: 30.10.2024
// Design Name: PYTHON VM top entity
// Module Name: top
// Project Name: PYTHON VM on FPGA
// Target Devices: BASYS 3 (ARTIX 7)
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module top(
    input CLK,
    input RESET,

    // Buttons
    input BTNR,
    
    // Leds
    output LD0,
    output LD1,
    output LD2,
    output [1:0] comm_ctrl_state,
    
    // Diplay 7
    output [7:0] Hex,
    output [3:0] Hex_select,
    
    // USB-UART
    input uart_rx,
    output uart_tx
    ); 
    
    // CLK divider reg
    reg [15:0] clk_div;
    
    // UART wires and regs
    wire uart_read_tick;
    wire uart_write_tick;
    wire rx_full, rx_empty;
    wire [7:0] uart_rec_data;
    wire [7:0] uart_send_data;
    reg [7:0] ticks;


    // display7 wires and regs
    wire [7:0] hex_byte1;

    assign LD0 = RESET;
    assign LD1 = rx_full;
    assign LD2 = rx_empty;
    // assign uart_send_data = 8'b0;
    
    // Clock divider
        // clk_div[0]  - Frequency = 50 MHz        | Period = 20 ns
        // clk_div[1]  - Frequency = 25 MHz        | Period = 40 ns
        // clk_div[2]  - Frequency = 12.5 MHz      | Period = 80 ns
        // clk_div[3]  - Frequency = 6.25 MHz      | Period = 160 ns
        // clk_div[4]  - Frequency = 3.125 MHz     | Period = 320 ns
        // clk_div[5]  - Frequency = 1.5625 MHz    | Period = 640 ns
        // clk_div[6]  - Frequency = 781.25 kHz    | Period = 1.28 µs
        // clk_div[7]  - Frequency = 390.62 kHz    | Period = 2.56 µs
        // clk_div[8]  - Frequency = 195.31 kHz    | Period = 5.12 µs
        // clk_div[9]  - Frequency = 97.65 kHz     | Period = 10.24 µs
        // clk_div[10] - Frequency = 48.82 kHz     | Period = 20.48 µs
        // clk_div[11] - Frequency = 24.41 kHz     | Period = 40.96 µs
        // clk_div[12] - Frequency = 12.20 kHz     | Period = 81.92 µs
        // clk_div[13] - Frequency = 6.10 kHz      | Period = 163.84 µs
        // clk_div[14] - Frequency = 3.05 kHz      | Period = 327.68 µs
        // clk_div[15] - Frequency = 1.52 kHz      | Period = 655.36 µs
    always @(posedge CLK or posedge RESET) begin
        if (RESET) 
            clk_div <= 0;
        else
            clk_div <= clk_div + 1;
    end

    always @(posedge clk_div[15] or posedge RESET) begin
        if (RESET) begin
            ticks <= 0;
        end
        else begin
            if (uart_read_tick) begin
                ticks <= ticks + 1;
            end
        end
    end
    
    // Seven segmente controller
    display7 d7(
        .clk_1KHz(clk_div[15]),
        .reset(RESET),
        .byte1(hex_byte1),
        .byte2(uart_rec_data),
        .Hex(Hex),
        .Hex_select(Hex_select)
    );
    
    // Complete UART Core
    uart_unity uart_top (
        .clk_100MHz(CLK),
        .reset(RESET),
        .read_uart(uart_read_tick),
        .write_uart(uart_write_tick),
        .rx(uart_rx),
        .write_data(uart_send_data),
        .rx_full(rx_full),
        .rx_empty(rx_empty),
        .read_data(uart_rec_data),
        .tx(uart_tx)
    );

    // Communication controller
    communication_controller comm_ctrl(
        .CLK(CLK),
        .RESET(RESET),
        .uart_rec_data(uart_rec_data),
        .rx_full(rx_full),
        .rx_empty(rx_empty),
        .uart_read_tick(uart_read_tick),
        .uart_write_tick(uart_write_tick),
        .uart_send_data(uart_send_data),
        .state(comm_ctrl_state),
        .debug(hex_byte1)
    );
    
endmodule
