`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 14:49:49
// Design Name: 
// Module Name: bram_stack
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


module bram_stack (
    input  wire        clk,
    input  wire        rst,
    input  wire        i_write_en,
    input  wire [7:0]  i_addr,
    input  wire [7:0]  i_type,
    input  wire [11:0] i_len,
    input  wire [11:0] i_ptr,
    output reg  [7:0]  o_type,
    output reg  [11:0] o_len,
    output reg  [11:0] o_ptr
);

    reg [31:0] mem [255:0]; // 256 x 32-bit memory

    always @(posedge clk) begin
        if (rst) begin
            o_type <= 0;
            o_len  <= 0;
            o_ptr  <= 0;
        end else begin
            if (i_write_en) begin
                mem[i_addr] <= {i_type, i_len, i_ptr};
            end
            
            {o_type, o_len, o_ptr} <= mem[i_addr];
        end
    end
endmodule