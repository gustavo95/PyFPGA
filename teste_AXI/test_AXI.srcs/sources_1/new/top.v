`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:
// Design Name:
// Module Name: top_mem_heap
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//   Top de teste para mem_heap
//
// Buttons:
//   BTN D = reset
//   BTN C = alloc
//   BTN U = write burst
//   BTN R = read burst
//
// Switches:
//   SW[4:0]   = len
//   SW[9:5]   = epoch
//   SW[13:10] = type[3:0]
//   SW[15:14] = seleção do display
//               00 -> data
//               01 -> idx
//               10 -> type
//               11 -> status
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
    output [3:0] o_hex_select
);

    // =========================================================
    // Debounce buttons
    // =========================================================
    wire w_btn_l;
    wire w_btn_r;
    wire w_btn_u;
    wire w_btn_d;
    wire w_btn_c;

    debounce db_btn_l (
        .clk(clk),
        .i_btn(i_btn_l),
        .o_btn(w_btn_l)
    );

    debounce db_btn_r (
        .clk(clk),
        .i_btn(i_btn_r),
        .o_btn(w_btn_r)
    );

    debounce db_btn_u (
        .clk(clk),
        .i_btn(i_btn_u),
        .o_btn(w_btn_u)
    );

    debounce db_btn_d (
        .clk(clk),
        .i_btn(i_btn_d),
        .o_btn(w_btn_d)
    );

    debounce db_btn_c (
        .clk(clk),
        .i_btn(i_btn_c),
        .o_btn(w_btn_c)
    );

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
    // Display
    // =========================================================
    reg [7:0] r_byte1_print;
    reg [7:0] r_byte2_print;

    // =========================================================
    // mem_heap interface
    // =========================================================
    reg        r_alloc_start;
    reg [4:0]  r_alloc_epoch;
    reg [7:0]  r_alloc_type;
    reg [4:0]  r_alloc_len;
    wire       w_alloc_ready;
    wire       w_alloc_done;
    wire       w_alloc_ok;
    wire [8:0] w_alloc_idx;
    wire       w_alloc_exception;

    reg        r_write_start;
    reg [8:0]  r_write_idx;
    reg [31:0] r_write_data;
    reg        r_write_tick;
    wire       w_write_ready;
    wire       w_write_done;
    wire       w_write_ok;
    wire       w_write_exception;

    reg        r_read_start;
    reg [8:0]  r_read_idx;
    wire [7:0]  w_read_type;
    wire [31:0] w_read_data;
    wire        w_read_ready;
    wire        w_read_tick;
    wire        w_read_done;
    wire        w_read_ok;
    wire        w_read_exception;

    // =========================================================
    // Registers for test control
    // =========================================================
    reg [8:0]  r_saved_idx;
    reg [4:0]  r_saved_len;
    reg [4:0]  r_saved_epoch;
    reg [7:0]  r_saved_type;

    reg [4:0]  r_wr_count;
    reg [31:0] r_last_rd_data;
    reg [7:0]  r_last_rd_type;

    reg        r_btn_c_prev;
    reg        r_btn_u_prev;
    reg        r_btn_r_prev;

    wire w_btn_c_pulse = w_btn_c & ~r_btn_c_prev;
    wire w_btn_u_pulse = w_btn_u & ~r_btn_u_prev;
    wire w_btn_r_pulse = w_btn_r & ~r_btn_r_prev;

    // =========================================================
    // Main FSM
    // =========================================================
    localparam T_IDLE       = 4'd0;
    localparam T_ALLOC_WAIT = 4'd1;
    localparam T_WR_WAIT    = 4'd2;
    localparam T_WR_NEXT    = 4'd3;
    localparam T_RD_WAIT    = 4'd4;

    reg [3:0] r_state;

    // =========================================================
    // Edge detect for buttons
    // =========================================================
    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            r_btn_c_prev <= 1'b0;
            r_btn_u_prev <= 1'b0;
            r_btn_r_prev <= 1'b0;
        end else begin
            r_btn_c_prev <= w_btn_c;
            r_btn_u_prev <= w_btn_u;
            r_btn_r_prev <= w_btn_r;
        end
    end

    // =========================================================
    // Test FSM
    // =========================================================
    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            r_state          <= T_IDLE;

            r_alloc_start    <= 1'b0;
            r_alloc_epoch    <= 5'd0;
            r_alloc_type     <= 8'd0;
            r_alloc_len      <= 5'd0;

            r_write_start    <= 1'b0;
            r_write_idx      <= 9'd0;
            r_write_data     <= 32'd0;
            r_write_tick     <= 1'b0;

            r_read_start     <= 1'b0;
            r_read_idx       <= 9'd0;

            r_saved_idx      <= 9'd0;
            r_saved_len      <= 5'd0;
            r_saved_epoch    <= 5'd0;
            r_saved_type     <= 8'd0;

            r_wr_count       <= 5'd0;
            r_last_rd_data   <= 32'd0;
            r_last_rd_type   <= 8'd0;
        end else begin
            case (r_state)
                T_IDLE: begin
                    // BTN C = alloc
                    if (w_btn_c_pulse) begin
                        r_alloc_len   <= i_sw[4:0];
                        r_alloc_epoch <= i_sw[9:5];
                        r_alloc_type  <= {4'd0, i_sw[13:10]};

                        r_saved_len   <= i_sw[4:0];
                        r_saved_epoch <= i_sw[9:5];
                        r_saved_type  <= {4'd0, i_sw[13:10]};

                        r_alloc_start <= 1'b1;
                        r_state       <= T_ALLOC_WAIT;
                    end
                    // BTN U = write burst
                    else if (w_btn_u_pulse) begin
                        r_write_idx   <= r_saved_idx;
                        r_write_data  <= 32'h00000001;
                        r_wr_count    <= 5'd0;
                        r_write_start <= 1'b1;
                        r_write_tick  <= 1'b1;
                        r_state       <= T_WR_WAIT;
                    end
                    // BTN R = read burst
                    else if (w_btn_r_pulse) begin
                        r_read_idx    <= r_saved_idx;
                        r_read_start  <= 1'b1;
                        r_state       <= T_RD_WAIT;
                    end
                end

                T_ALLOC_WAIT: begin
                    r_alloc_start <= 1'b0;
                    if (w_alloc_done) begin
                        if (w_alloc_ok) begin
                            r_saved_idx <= w_alloc_idx;
                        end
                        r_state <= T_IDLE;
                    end
                end

                T_WR_WAIT: begin
                    r_write_start <= 1'b0;
                    if (w_write_done) begin
                        r_write_tick <= 1'b0;
                        r_state <= T_IDLE;
                    end
                    else if (w_write_ok) begin
                        r_write_tick <= 1'b0;
                        r_state      <= T_WR_NEXT;
                    end
                end

                T_WR_NEXT: begin
                    if (!w_write_ok) begin
                        r_wr_count   <= r_wr_count + 1'b1;
                        r_write_data <= r_write_data + 1;
                        r_write_tick <= 1'b1;
                        r_state      <= T_WR_WAIT;
                    end
                end

                T_RD_WAIT: begin
                    r_read_start <= 1'b0;
                    if (w_read_tick) begin
                        r_last_rd_data <= w_read_data;
                        r_last_rd_type <= w_read_type;
                    end
                    if (w_read_done) begin
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
    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            o_led <= 16'd0;
        end else begin
            o_led[5:0] <= r_saved_idx[5:0];
            o_led[6]   <= w_alloc_exception;
            o_led[7]   <= w_write_exception;
            o_led[8]   <= w_read_exception;
            if (w_alloc_ok)   o_led[9]  <= 1'b1;
            if (w_write_ok)   o_led[10] <= 1'b1;
            if (w_read_tick)  o_led[11] <= 1'b1;
            if (w_alloc_done) o_led[12] <= 1'b1;
            if (w_write_done) o_led[13] <= 1'b1;
            if (w_read_done)  o_led[14] <= 1'b1;
            o_led[15]        <= (r_state != T_IDLE);
        end
    end

    // =========================================================
    // Display select
    // SW[15:14]
    // 00 = last read data[15:0]
    // 01 = saved idx
    // 10 = last read type
    // 11 = status
    // =========================================================
    always @(*) begin
        case (i_sw[15:14])
            2'b00: begin
                r_byte1_print = r_last_rd_data[7:0];
                r_byte2_print = r_last_rd_data[15:8];
            end

            2'b01: begin
                r_byte1_print = {7'd0, r_saved_idx[0]};
                r_byte2_print = {r_saved_idx[8:1]};
            end

            2'b10: begin
                r_byte1_print = r_last_rd_type;
                r_byte2_print = 8'd0;
            end

            2'b11: begin
                r_byte1_print = {4'd0, r_state};
                r_byte2_print = {
                    1'b0,
                    w_alloc_exception,
                    w_write_exception,
                    w_read_exception,
                    w_alloc_done,
                    w_write_done,
                    w_read_done,
                    (r_state != T_IDLE)
                };
            end

            default: begin
                r_byte1_print = 8'h00;
                r_byte2_print = 8'h00;
            end
        endcase
    end

    display7 d7(
        .clk_1KHz(clk_div[15]),
        .rst(w_btn_d),
        .i_byte1(r_byte1_print),
        .i_byte2(r_byte2_print),
        .o_hex(o_hex),
        .o_hex_select(o_hex_select)
    );

    // =========================================================
    // DUT
    // =========================================================
    mem_heap mem_heap_inst (
        .clk(clk),
        .rst(w_btn_d),

        .i_alloc_start(r_alloc_start),
        .i_alloc_epoch(r_alloc_epoch),
        .i_alloc_type(r_alloc_type),
        .i_alloc_len(r_alloc_len),
        .o_alloc_ready(w_alloc_ready),
        .o_alloc_done(w_alloc_done),
        .o_alloc_ok(w_alloc_ok),
        .o_alloc_idx(w_alloc_idx),
        .o_alloc_exception(w_alloc_exception),

        .i_write_start(r_write_start),
        .i_write_idx(r_write_idx),
        .i_write_data(r_write_data),
        .i_write_tick(r_write_tick),
        .o_write_ready(w_write_ready),
        .o_write_done(w_write_done),
        .o_write_ok(w_write_ok),
        .o_write_exception(w_write_exception),

        .i_read_start(r_read_start),
        .i_read_idx(r_read_idx),
        .o_read_type(w_read_type),
        .o_read_data(w_read_data),
        .o_read_ready(w_read_ready),
        .o_read_tick(w_read_tick),
        .o_read_done(w_read_done),
        .o_read_ok(w_read_ok),
        .o_read_exception(w_read_exception)
    );

endmodule
