`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.08.2026 20:24:23
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
    input clk,
    input reset,
    input [7:0] uart_rec_data,
    input rx_empty,
    input tx_full,
    output reg [7:0] uart_send_data,
    output reg uart_write_tick,
    output reg uart_read_tick,
    output reg [31:0] word_buffer
    );

reg [3:0] state;

reg [2:0] byte_index;
reg [3:0] received_word_count;

localparam WAIT_START      = 4'd0;
localparam SEND_START_ACK  = 4'd1;
localparam WAIT_COMMAND    = 4'd2;
localparam RELEASE_COMMAND = 4'd3;
localparam READ_WORD_BYTE  = 4'd4;
localparam RELEASE_WORD_BYTE = 4'd5;
localparam WORD_READY      = 4'd6;
localparam SEND_WORD_ACK   = 4'd7;
localparam FINISH          = 4'd8;
localparam SEND_DONE       = 4'd9;
localparam ERROR           = 4'd10;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        uart_send_data <= 8'h00;
        uart_write_tick <= 1'b0;
        uart_read_tick <= 1'b0;
        word_buffer <= 32'h0;
        byte_index <= 3'h0;
        received_word_count <= 4'h0;
        state <= WAIT_START;
    end
    else begin
        case (state)
            WAIT_START: begin
                uart_write_tick <= 1'b0;
                if (!rx_empty) begin
                    uart_read_tick <= 1'b1;
                    if (uart_rec_data == 8'hA5) begin
                        state <= SEND_START_ACK;
                    end
                    else begin
                        state <= ERROR;
                    end
                end
                else begin
                    uart_read_tick <= 1'b0;
                end
            end
            SEND_START_ACK: begin
                uart_read_tick <= 1'b0;
                if (!tx_full) begin
                    uart_send_data <= 8'h79;
                    uart_write_tick <= 1'b1;
                    state <= WAIT_COMMAND;
                end
            end
            WAIT_COMMAND: begin
                uart_write_tick <= 1'b0;
                if (!rx_empty) begin
                    uart_read_tick <= 1'b1;
                    if (uart_rec_data == 8'hA6) begin
                        state <= RELEASE_COMMAND;
                    end
                    else if (uart_rec_data == 8'h7A) begin
                        state <= FINISH;
                    end
                    else begin
                        state <= ERROR;
                    end
                end
            end
            RELEASE_COMMAND: begin
                uart_read_tick <= 1'b0;
                byte_index <= 3'd0;
                state <= READ_WORD_BYTE;
            end
            READ_WORD_BYTE: begin
                if (!rx_empty) begin
                    uart_read_tick <= 1'b1;
                    word_buffer <= {word_buffer[23:0], uart_rec_data};
                    byte_index <= byte_index + 1;
                    state <= RELEASE_WORD_BYTE;
                end
            end
            RELEASE_WORD_BYTE: begin
                uart_read_tick <= 1'b0;
                if (byte_index == 3'd4) begin
                    state <= WORD_READY;
                end
                else begin
                    state <= READ_WORD_BYTE;
                end
            end
            WORD_READY: begin
                uart_read_tick <= 1'b0;
                received_word_count <= received_word_count + 1;
                state <= SEND_WORD_ACK;
            end
            SEND_WORD_ACK: begin
                if (!tx_full) begin
                    uart_send_data <= 8'h79;
                    uart_write_tick <= 1'b1;
                    state <= WAIT_COMMAND;
                end
            end
            FINISH: begin
                uart_write_tick <= 1'b0;
                uart_read_tick <= 1'b0;
                state <= SEND_DONE;
            end
            SEND_DONE: begin
                if (!tx_full) begin
                    uart_send_data <= 8'h7A;
                    uart_write_tick <= 1'b1;
                    state <= WAIT_START;
                end
            end
            ERROR: begin
                uart_write_tick <= 1'b0;
                uart_read_tick <= 1'b0;
                state <= WAIT_START;
            end     
            default: begin
                state <= WAIT_START;
            end
        endcase
    end  
end

endmodule
