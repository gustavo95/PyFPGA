`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:
// Design Name:
// Module Name: top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//   Top de teste para o flash_driver / axi_quad_spi_0.
//
// Buttons:
//   BTN D = reset
//   BTN C = sem uso
//   BTN U = escreve SW[7:0] em IPIER
//   BTN R = le IPIER
//   BTN L = le SPISR
//
// Switches:
//   SW[7:0] = valor de escrita para IPIER
//
// Display:
//   mostra os 16 bits menos significativos da ultima leitura
//////////////////////////////////////////////////////////////////////////////////

module top(
    input clk,

    // Buttons
    input i_btn_l,
    input i_btn_r,
    input i_btn_u,
    input i_btn_d,
    input i_btn_c,

    // Switches
    input [15:0] i_sw,

    // LEDs
    output reg [15:0] o_led,

    // Display 7 segmentos
    output [7:0] o_hex,
    output [3:0] o_hex_select,

    // QSPI pins - Flash memory interface
    inout        qspi_dq0,
    inout        qspi_dq1,
    inout        qspi_dq2,
    inout        qspi_dq3,
    inout        qspi_cs_n,

       // USB-UART
    input usb_uart_rx,
    output usb_uart_tx
);

    localparam [6:0] REG_IPIER   = 7'h28;
    localparam [6:0] REG_SPISR   = 7'h64;

    localparam [3:0] ST_IDLE          = 4'd0;
    localparam [3:0] ST_WAIT_OP       = 4'd1;

    // =========================================================
    // Debounce buttons
    // =========================================================
    wire w_btn_l;
    wire w_btn_r;
    wire w_btn_u;
    wire w_btn_d;
    wire w_btn_c;

    debounce db_btn_l (.clk(clk), .i_btn(i_btn_l), .o_btn(w_btn_l));
    debounce db_btn_r (.clk(clk), .i_btn(i_btn_r), .o_btn(w_btn_r));
    debounce db_btn_u (.clk(clk), .i_btn(i_btn_u), .o_btn(w_btn_u));
    debounce db_btn_d (.clk(clk), .i_btn(i_btn_d), .o_btn(w_btn_d));
    debounce db_btn_c (.clk(clk), .i_btn(i_btn_c), .o_btn(w_btn_c));

    // =========================================================
    // Clock divider
    // =========================================================
    wire [15:0] clk_div;

    clk_div clk_div_inst (
        .clk(clk),
        .rst(w_btn_d),
        .clk_div(clk_div)
    );

    // =========================================================
    // Edge detect
    // =========================================================
    reg r_btn_l_prev;
    reg r_btn_r_prev;
    reg r_btn_u_prev;

    wire w_btn_l_pulse = w_btn_l & ~r_btn_l_prev;
    wire w_btn_r_pulse = w_btn_r & ~r_btn_r_prev;
    wire w_btn_u_pulse = w_btn_u & ~r_btn_u_prev;

    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            r_btn_l_prev <= 1'b0;
            r_btn_r_prev <= 1'b0;
            r_btn_u_prev <= 1'b0;
        end else begin
            r_btn_l_prev <= w_btn_l;
            r_btn_r_prev <= w_btn_r;
            r_btn_u_prev <= w_btn_u;
        end
    end

    // =========================================================
    // Display regs
    // =========================================================
    reg [7:0] r_byte1_print;
    reg [7:0] r_byte2_print;
    wire [31:0] word_buffer;

    // =========================================================
    // Flash_driver interface
    // =========================================================
    reg        r_flash_start;
    reg        r_flash_write;
    reg [6:0]  r_flash_addr;
    reg [31:0] r_flash_wdata;
    reg [3:0]  r_flash_wstrb;
    wire       w_flash_ready;
    wire       w_flash_busy;
    wire       w_flash_done;
    wire [31:0] w_flash_rdata;
    wire [1:0]  w_flash_resp;
    wire        w_flash_error;

    // =========================================================
    // Uart wires
    // =========================================================
    wire uart_read_tick;
    wire uart_write_tick;
    wire rx_full, rx_empty, tx_full;
    wire [7:0] uart_rec_data;
    wire [7:0] uart_send_data;

    // =========================================================
    // Display aplication
    // =========================================================
    always @(*) begin
        r_byte1_print = word_buffer[15:8];
        r_byte2_print = word_buffer[7:0];
    end

    display7 d7(
        .clk_1KHz(clk_div[15]),
        .rst(w_btn_d),
        .i_byte1(r_byte1_print),
        .i_byte2(r_byte2_print),
        .o_hex(o_hex),
        .o_hex_select(o_hex_select)
    );

    uart_unity uart_top (
        .clk_100MHz(clk),
        .reset(w_btn_d),
        .read_uart(uart_read_tick),
        .write_uart(uart_write_tick),
        .rx(usb_uart_rx),
        .write_data(uart_send_data),
        .rx_full(rx_full),
        .rx_empty(rx_empty),
        .tx(usb_uart_tx),
        .read_data(uart_rec_data),
        .tx_full(tx_full)
    );

    communication_controller comm_ctrl (
        .clk(clk),
        .reset(w_btn_d),
        .uart_rec_data(uart_rec_data),
        .rx_empty(rx_empty),
        .tx_full(tx_full),
        .uart_send_data(uart_send_data),
        .uart_write_tick(uart_write_tick),
        .uart_read_tick(uart_read_tick),
        .word_buffer(word_buffer)
    );


endmodule
