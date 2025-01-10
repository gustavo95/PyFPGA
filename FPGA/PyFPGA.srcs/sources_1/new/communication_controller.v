`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.12.2024 19:23:44
// Design Name: 
// Module Name: communication_controller
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


module communication_controller(
    input CLK,
    input RESET,
    input [7:0] uart_rec_data,
    input rx_full,
    input rx_empty,
    output reg uart_read_tick,
    output reg uart_write_tick,
    output reg [7:0] uart_send_data,
    output reg [1:0] state,
    output reg [7:0] debug
    );

    // States
    localparam WAIT_COMMAND = 2'b00;
    localparam RUN_COMMAND = 2'b01;
    localparam WAIT_CODE = 2'b10;
    localparam SAVE_CODE = 2'b11;

    reg [7:0] read_data;


    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state <= WAIT_COMMAND;
            uart_read_tick <= 0;
            uart_write_tick <= 0;
            uart_send_data <= 8'b0;
            debug <= 8'b0;
            read_data <= 8'b0;
        end else begin
            case (state)
                WAIT_COMMAND: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= RUN_COMMAND;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                RUN_COMMAND: begin
                    uart_read_tick <= 0;
                    if (read_data == 8'h30) begin
                        state <= WAIT_CODE;
                    end
                    else begin
                        state <= WAIT_COMMAND;
                    end
                end
                WAIT_CODE: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= SAVE_CODE;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                SAVE_CODE: begin
                    uart_read_tick <= 0;
                    if (read_data == 8'h30) begin
                        state <= WAIT_COMMAND;
                    end else begin
                        debug <= read_data;
                        state <= WAIT_CODE;
                    end
                end
                default: state <= WAIT_CODE;
            endcase
        end
    end
    

endmodule
