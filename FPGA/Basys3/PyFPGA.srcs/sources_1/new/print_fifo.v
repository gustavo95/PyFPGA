`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2025 15:29:03
// Design Name: 
// Module Name: print_fifo
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


module print_fifo(
    input CLK,
    input RESET,
    input fifo_pop,
    input fifo_save,
    input [31:0] argval_in,
    output fifo_full,
    output fifo_empty,
    output reg [31:0] argval_out
);

    // FIFO interna para os campos do argval
    reg [31:0] fifo_argval [3:0];     // Valores do argval (64 bits)

    // Controle da FIFO
    reg [1:0] read_ptr, write_ptr;    // Ponteiros de leitura/escrita
    reg [3:0] fifo_count;             // Contador de elementos na FIFO

    assign fifo_full = (fifo_count == 4'd4);
    assign fifo_empty = (fifo_count == 4'd0);

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // Resetar a FIFO
            fifo_count <= 0;
            read_ptr <= 0;
            write_ptr <= 0;
        end else begin
            // Salvar na FIFO (escrita)
            if (fifo_save && !fifo_full) begin
                fifo_argval[write_ptr] <= argval_in;

                write_ptr <= write_ptr + 3'd1;
                fifo_count <= fifo_count + 4'd1;
            end
            // Ler da FIFO (leitura)
            else if (fifo_pop && !fifo_empty) begin
                argval_out <= fifo_argval[read_ptr];
                
                read_ptr <= read_ptr + 3'd1;
                fifo_count <= fifo_count - 4'd1;
            end
        end
    end
endmodule
