`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 15:30:57
// Design Name: 
// Module Name: clk_div
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


module clk_div(
    input clk,
    input rst,
    output [15:0] clk_div
    );

reg [15:0] clk_div;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_div <= 0;
    end else begin
        clk_div <= clk_div + 1;
    end
end
endmodule
