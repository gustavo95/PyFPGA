`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UFRN
// Engineer: Gustavo Costa Gomes de Melo
// 
// Create Date: 23.06.2025 19:09:36
// Design Name: PYTHON VM top entity
// Module Name: top
// Project Name: PYTHON VM on FPGA
// Target Devices: USB104 A7 (ARTIX 7)
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
    input RESET, // BTN1

    // Buttons
    input BTN0,

    // Leds
    output reg LD0,
    output reg LD1,
    output reg LD2,
    output reg LD3,

    // USB-UART Bridge
    input uart_rx,
    output uart_tx,

    // SPI Flash
    output spi_sck,
    output spi_cs,
    inout spi_sdi_dq0,
    inout spi_sdo_dq1,
    inout spi_wp_dq2,
    inout spi_hold_dq3
    );

    // State control
    reg BTN0_prev;

    // UART wires and regs
    wire uart_read_tick;
    reg uart_write_tick;
    wire rx_full, rx_empty;
    wire [7:0] uart_rec_data;
    reg [7:0] uart_send_data;

    // SPI wires and regs
    reg start_spi;
    wire spi_done;
    wire [7:0] spi_data;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            LD0 <= 0;
            LD1 <= 0;
            LD2 <= 0;
            LD3 <= 0;
            uart_write_tick <= 0;
        end else begin
            // Example logic to toggle LEDs based on BTN0
            if (BTN0 && !BTN0_prev) begin
                LD0 <= ~LD0;
                LD1 <= ~LD1;
                LD2 <= ~LD2;
                LD3 <= ~LD3;
                start_spi <= 1;
            end

            if (spi_done) begin
                uart_send_data <= spi_data;
                start_spi <= 0;
                uart_write_tick <= 1; // Trigger UART write
            end else begin
                uart_write_tick <= 0; // Reset UART write tick
            end

            BTN0_prev <= BTN0;
        end
    end

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


    quad_spi_masterinput flash_spi(
        .clk(CLK),
        .reset(RESET),
        .start(start_spi),
        .done(spi_done),
        .id_out(spi_data),
        .sck(spi_sck),
        .cs_n(spi_cs),
        .mosi(spi_sdi_dq0),
        .miso(spi_sdo_dq1)
    );
endmodule
