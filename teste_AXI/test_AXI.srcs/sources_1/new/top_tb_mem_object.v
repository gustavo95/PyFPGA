`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 14:29:26
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
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


module top_tb_mem_object(
    input clk,

    // Buttons
    input i_btn_l,
    input i_btn_r,
    input i_btn_u,
    input i_btn_d,
    input i_btn_c,

    // Switches
    input [15:0] i_sw,

    // Leds
    output reg [15:0] o_led,

    // Diplay 7
    output [7:0] o_hex,
    output [3:0] o_hex_select
);

// =========================================================
    // Clock divider
    // =========================================================
    wire [15:0] clk_div;

    clk_div clk_div_inst (
        .clk(clk),
        .rst(i_btn_d),   // botão down como reset geral
        .clk_div(clk_div)
    );

    // =========================================================
    // Display
    // =========================================================
    wire [7:0] w_byte1_print;
    wire [7:0] w_byte2_print;

    // =========================================================
    // mem_data interface
    // =========================================================
    reg        r_alloc_start;
    reg [4:0]  r_alloc_len;
    reg [4:0]  r_alloc_epoch;
    wire       w_alloc_ready;
    wire       w_alloc_done;
    wire       w_alloc_ok;
    wire [8:0] w_alloc_ptr;

    reg        r_wr_start;
    reg [8:0]  r_wr_ptr;
    reg [4:0]  r_wr_len;
    reg [31:0] r_wr_data;
    reg        r_wr_tick;
    wire       w_wr_ready;
    wire       w_wr_done;
    wire       w_wr_ok;

    reg        r_rd_start;
    reg [8:0]  r_rd_ptr;
    reg [4:0]  r_rd_len;
    wire [31:0] w_rd_data;
    wire       w_rd_ready;
    wire [4:0] w_rd_idx;
    wire       w_rd_done;
    wire       w_rd_ok;
    wire       w_rd_tick;

    // =========================================================
    // Registers for test control
    // =========================================================
    reg [8:0]  r_saved_ptr;
    reg [4:0]  r_saved_len;
    reg [4:0]  r_saved_epoch;

    reg [4:0]  r_wr_count;
    reg [31:0] r_last_rd_data;

    reg        r_btn_c_prev;
    reg        r_btn_u_prev;
    reg        r_btn_r_prev;

    wire w_btn_c_pulse = i_btn_c & ~r_btn_c_prev;
    wire w_btn_u_pulse = i_btn_u & ~r_btn_u_prev;
    wire w_btn_r_pulse = i_btn_r & ~r_btn_r_prev;

    // =========================================================
    // Main FSM
    // =========================================================
    localparam T_IDLE       = 4'd0;
    localparam T_ALLOC_REQ  = 4'd1;
    localparam T_ALLOC_WAIT = 4'd2;
    localparam T_WR_REQ     = 4'd3;
    localparam T_WR_WAIT    = 4'd4;
    localparam T_WR_NEXT    = 4'd5;
    localparam T_RD_REQ     = 4'd6;
    localparam T_RD_WAIT    = 4'd7;

    reg [3:0] r_state;

    // =========================================================
    // Edge detect for buttons
    // =========================================================
    always @(posedge clk or posedge i_btn_d) begin
        if (i_btn_d) begin
            r_btn_c_prev <= 1'b0;
            r_btn_u_prev <= 1'b0;
            r_btn_r_prev <= 1'b0;
        end else begin
            r_btn_c_prev <= i_btn_c;
            r_btn_u_prev <= i_btn_u;
            r_btn_r_prev <= i_btn_r;
        end
    end

    // =========================================================
    // Test FSM
    // =========================================================
    always @(posedge clk or posedge i_btn_d) begin
        if (i_btn_d) begin
            r_state       <= T_IDLE;

            r_alloc_start <= 1'b0;
            r_alloc_len   <= 5'd0;
            r_alloc_epoch <= 5'd0;

            r_wr_start    <= 1'b0;
            r_wr_ptr      <= 9'd0;
            r_wr_len      <= 5'd0;
            r_wr_data     <= 32'd0;
            r_wr_tick     <= 1'b0;

            r_rd_start    <= 1'b0;
            r_rd_ptr      <= 9'd0;
            r_rd_len      <= 5'd0;

            r_saved_ptr   <= 9'd0;
            r_saved_len   <= 5'd0;
            r_saved_epoch <= 5'd0;

            r_wr_count    <= 5'd0;
            r_last_rd_data<= 32'd0;
        end else begin
            case (r_state)
                T_IDLE: begin
                    // BTN C = alloc
                    if (w_btn_c_pulse) begin
                        r_alloc_len   <= i_sw[4:0];
                        r_alloc_epoch <= i_sw[9:5];
                        r_saved_len   <= i_sw[4:0];
                        r_saved_epoch <= i_sw[9:5];
                        r_alloc_start <= 1'b1;
                        r_state       <= T_ALLOC_WAIT;
                    end
                    // BTN U = write burst
                    else if (w_btn_u_pulse) begin
                        r_wr_ptr      <= r_saved_ptr;
                        r_wr_len      <= r_saved_len;
                        // r_wr_ptr      <= 9'd0;
                        // r_wr_len      <= 5'd2;
                        r_wr_data     <= 32'h00000001;
                        r_wr_count    <= 5'd0;
                        r_wr_start    <= 1'b1;
                        r_wr_tick     <= 1'b1;
                        r_state       <= T_WR_WAIT;
                    end
                    // BTN R = read burst
                    else if (w_btn_r_pulse) begin
                        r_rd_ptr      <= r_saved_ptr;
                        r_rd_len      <= r_saved_len;
                        // r_rd_ptr      <= 9'd0;
                        // r_rd_len      <= 5'd2;
                        r_rd_start    <= 1'b1;
                        r_state       <= T_RD_WAIT;
                    end
                end

                T_ALLOC_WAIT: begin
                    r_alloc_start <= 1'b0;
                    if (w_alloc_done) begin
                        if (w_alloc_ok) begin
                            r_saved_ptr <= w_alloc_ptr;
                        end
                        r_state <= T_IDLE;
                    end
                end

                T_WR_WAIT: begin
                    r_wr_start <= 1'b0;
                    if (w_wr_done) begin
                        r_wr_tick <= 1'b0;
                        r_state <= T_IDLE;
                    end
                    else if (w_wr_ok) begin
                        r_wr_tick <= 1'b0;
                        r_state   <= T_WR_NEXT;
                    end
                end

                T_WR_NEXT: begin
                    if(!w_wr_ok) begin
                        r_wr_data <= r_wr_data + 1;
                        // r_wr_data <= 32'h00000010;
                        r_wr_tick <= 1'b1;
                        r_state   <= T_WR_WAIT;
                    end
                end

                T_RD_WAIT: begin
                    r_rd_start    <= 1'b0;
                    if (w_rd_done) begin
                        r_last_rd_data <= w_rd_data;
                        r_state <= T_IDLE;
                    end
                end

                default: begin
                    r_state <= T_IDLE;
                end
            endcase
        end
    end

    // =========================================================
    // LEDs
    // =========================================================
    always @(posedge clk or posedge i_btn_d) begin
        if (i_btn_d) begin
            o_led[15:0] <= 16'd0;
        end else begin
            o_led[8:0] <= r_saved_ptr;
            if (w_alloc_ok) o_led[9] <= 1'b1;
            if (w_wr_ok)    o_led[10] <= 1'b1;
            o_led[11] <= w_rd_tick;
            if (w_alloc_done) o_led[12] <= 1'b1;
            if (w_wr_done)    o_led[13] <= 1'b1;
            if (w_rd_done)    o_led[14] <= 1'b1;
            o_led[15] <= (r_state != T_IDLE);

            // o_led[0] <= w_rd_ready;
            // if (!w_rd_ready) o_led[1] <= 1'b1;
            // if (w_rd_idx[0]) o_led[2] <= 1'b1;
            // if (w_rd_done) o_led[3] <= 1'b1;
            // if (w_rd_ok) o_led[4] <= 1'b1;
            // if (w_rd_tick) o_led[5] <= 1'b1;

            // o_led[0] <= w_wr_ready;
            // if (!w_wr_ready) o_led[1] <= 1'b1;
            // if (w_wr_ok) o_led[2] <= 1'b1;
            // if (w_wr_done) o_led[3] <= 1'b1;
            // o_led[4] <= r_wr_tick;
            // o_led[8:5] <= r_state;
            // if (r_wr_tick) o_led[9] <= 1'b1;
        end
    end

    // =========================================================
    // Display:
    // default mostra 16 bits baixos do último dado lido
    // se SW15=1, mostra ponteiro salvo
    // =========================================================
    assign w_byte1_print = i_sw[15] ? {7'd0, r_saved_ptr[0]} : r_last_rd_data[7:0];
    assign w_byte2_print = i_sw[15] ? {3'd0, r_saved_ptr[8:1]} : r_last_rd_data[15:8];

    display7 d7(
        .clk_1KHz(clk_div[15]),
        .rst(i_btn_d),
        .i_byte1(w_byte1_print),
        .i_byte2(w_byte2_print),
        .o_hex(o_hex),
        .o_hex_select(o_hex_select)
    );

    // =========================================================
    // DUT
    // =========================================================
    mem_data mem_data_inst (
        .clk(clk),
        .rst(i_btn_d),

        .i_alloc_start(r_alloc_start),
        .i_alloc_len(r_alloc_len),
        .i_alloc_epoch(r_alloc_epoch),
        .o_alloc_ready(w_alloc_ready),
        .o_alloc_done(w_alloc_done),
        .o_alloc_ok(w_alloc_ok),
        .o_alloc_ptr(w_alloc_ptr),

        .i_wr_start(r_wr_start),
        .i_wr_ptr(r_wr_ptr),
        .i_wr_len(r_wr_len),
        .i_wr_data(r_wr_data),
        .i_wr_tick(r_wr_tick),
        .o_wr_ready(w_wr_ready),
        .o_wr_done(w_wr_done),
        .o_wr_ok(w_wr_ok),

        .i_rd_start(r_rd_start),
        .i_rd_ptr(r_rd_ptr),
        .i_rd_len(r_rd_len),
        .o_rd_data(w_rd_data),
        .o_rd_ready(w_rd_ready),
        .o_rd_idx(w_rd_idx),
        .o_rd_done(w_rd_done),
        .o_rd_ok(w_rd_ok),
        .o_rd_tick(w_rd_tick)
    );


endmodule
