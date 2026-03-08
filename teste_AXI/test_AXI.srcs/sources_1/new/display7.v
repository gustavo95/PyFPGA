`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.10.2024 20:07:10
// Design Name: 
// Module Name: display7
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


module display7(
    input clk_1KHz,
    input rst,
    input [7:0] i_byte1,
    input [7:0] i_byte2,
    output reg [7:0] o_hex,
    output reg [3:0] o_hex_select
    );
    
    reg [1:0] display_select;
    reg [7:0] character;
    reg [3:0] input_val;
    
    always @ (posedge clk_1KHz or posedge rst) begin
        if (rst) begin
            display_select <= 2'd0;
            o_hex_select <= 4'b1111;
            o_hex <= 8'b11111111;
        end
        else begin
            case (display_select)
                2'd0: begin
                    o_hex_select <= 4'b1110;
                    o_hex <= character;
                end
                2'd1: begin
                    o_hex_select <= 4'b1101;
                    o_hex <= character;
                end
                2'd2: begin
                    o_hex_select <= 4'b1011;
                    o_hex <= character;
                end
                2'd3: begin
                    o_hex_select <= 4'b0111;
                    o_hex <= character;
                end
            endcase
            display_select <= display_select + 1'b1;
        end
    end
    
    always @ (*) begin
        case (display_select)
            2'd0: input_val = i_byte1[3:0];
            2'd1: input_val = i_byte1[7:4];
            2'd2: input_val = i_byte2[3:0];
            2'd3: input_val = i_byte2[7:4];
        endcase
        case (input_val)
            8'd0: character = 8'b11000000; // Exibe 0
            8'd1: character = 8'b11111001; // Exibe 1
            8'd2: character = 8'b10100100; // Exibe 2
            8'd3: character = 8'b10110000; // Exibe 3
            8'd4: character = 8'b10011001; // Exibe 4
            8'd5: character = 8'b10010010; // Exibe 5
            8'd6: character = 8'b10000010; // Exibe 6
            8'd7: character = 8'b11111000; // Exibe 7
            8'd8: character = 8'b10000000; // Exibe 8
            8'd9: character = 8'b10010000; // Exibe 9
            8'd10: character = 8'b10001000; // Exibe A
            8'd11: character = 8'b10000011; // Exibe B
            8'd12: character = 8'b11000110; // Exibe C
            8'd13: character = 8'b10100001; // Exibe D
            8'd14: character = 8'b10000110; // Exibe E
            8'd15: character = 8'b10001110; // Exibe F
            default: character = 8'b11111111;
        endcase
    end
    
endmodule
