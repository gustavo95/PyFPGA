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

    // Leds
    output [15:0] o_led,

    // Diplay 7
    output [7:0] o_hex,
    output [3:0] o_hex_select
);

// CLK divider reg
wire [15:0] clk_div;

// 7-segment display bytes
wire [7:0] w_byte1_print;
wire [7:0] w_byte2_print;

// Stack BRAM signals
reg r_stack_write_en;
reg [7:0] r_stack_addr;
reg [7:0] r_stack_type;
reg [11:0] r_stack_len;
reg [11:0] r_stack_ptr;
wire [7:0] w_stack_type;
wire [11:0] w_stack_len;
wire [11:0] w_stack_ptr;

// Logic signals
reg [7:0] r_max_addr;
reg r_btn_pressed;

clk_div clk_div_inst (
    .clk(clk),
    .rst(i_btn_r),
    .clk_div(clk_div)
);

assign o_led[12] = i_btn_r;
assign o_led[13] = !i_sw[0];
assign o_led[14] = (i_sw[0] && !i_sw[1]);
assign o_led[15] = (i_sw[0] && i_sw[1]);

assign o_led[7:0] = r_stack_addr;

assign w_byte1_print = i_sw[0] ? (i_sw[1] ?  w_stack_ptr[7:0] : w_stack_len[7:0]) : w_stack_type;
assign w_byte2_print = i_sw[0] ? (i_sw[1] ?  {4'h0, w_stack_ptr[11:8]} : {4'h0, w_stack_len[11:8]}) : 8'h00;

always @(posedge clk or posedge i_btn_r) begin
    if (i_btn_r) begin
        r_stack_write_en <= 0;
        r_stack_addr <= 8'hFF;
        r_stack_type <= 0;
        r_stack_len <= 0;
        r_stack_ptr <= 0;
        r_max_addr <= 8'hFF;
        r_btn_pressed <= 0;
    end else begin
        if (i_btn_u && (r_stack_addr == r_max_addr) && !r_btn_pressed) begin
            r_stack_write_en <= 1;
            r_stack_addr <= r_stack_addr + 1;
            r_stack_type <= r_stack_type + 1;
            r_stack_len <= r_stack_len + 1;
            r_stack_ptr <= r_stack_ptr + 1;
            r_max_addr <= r_max_addr + 1;
            r_btn_pressed <= 1;
        end else if (i_btn_u && !r_btn_pressed) begin
            r_stack_addr <= r_stack_addr + 1;
            r_btn_pressed <= 1;
        end else if (i_btn_d && r_stack_addr > 0 && !r_btn_pressed) begin
            r_stack_write_en <= 0;
            r_stack_addr <= r_stack_addr - 1;
            r_btn_pressed <= 1;
        end else if (!i_btn_u && !i_btn_d) begin
            r_stack_write_en <= 0;
            r_btn_pressed <= 0;
        end else begin
            r_stack_write_en <= 0;
        end
    end
end

display7 d7(
    .clk_1KHz(clk_div[15]),
    .rst(i_btn_r),
    .i_byte1(w_byte1_print),
    .i_byte2(w_byte2_print),
    .o_hex(o_hex),
    .o_hex_select(o_hex_select)
);

mem_object obj (
    .clk(clk),
    .rst(i_btn_r),
    .i_write_en(r_stack_write_en),
    .i_addr(r_stack_addr),
    .i_type(r_stack_type),
    .i_len(r_stack_len),
    .i_ptr(r_stack_ptr),
    .o_type(w_stack_type),
    .o_len(w_stack_len),
    .o_ptr(w_stack_ptr)
);

endmodule
