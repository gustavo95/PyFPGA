`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.06.2025 20:37:58
// Design Name: 
// Module Name: quad_spi_master
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


module quad_spi_masterinput(
    input wire clk,          // clock do sistema
    input  wire reset,
    input  wire start,        // sinal de início
    output reg  done,         // sinal de fim
    output reg [7:0] id_out,

    // SPI sinais
    output reg sck,
    output reg cs_n,
    output reg mosi,
    input  wire miso
);

    reg [7:0] tx_buffer [0:0];  // apenas 1 byte: o comando 0x9F
    reg [2:0] rx_index = 0;     // para 3 bytes
    reg [7:0] rx_shift;
    reg [7:0] rx_data [0:3];
    reg [2:0] bit_cnt;

    reg [3:0] state;
    localparam IDLE   = 0,
               ASSERT = 1,
               SEND   = 2,
               RECV   = 3,
               DONE   = 4;

    reg [3:0] clk_div;
    wire tick = (clk_div == 4);  // ajusta aqui para sua velocidade de SPI

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div <= 0;
        end else begin
            clk_div <= (tick ? 0 : clk_div + 1);
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            done      <= 0;
            cs_n      <= 1;
            sck       <= 0;
            mosi      <= 0;
            rx_index  <= 0;
            id_out    <= 0;
        end else if (tick) begin
            case (state)
                IDLE: begin
                    done <= 0;
                    sck <= 0;
                    rx_index <= 0;
                    if (start) begin
                        tx_buffer[0] <= 8'h9F;  // comando JEDEC ID
                        cs_n <= 0;
                        bit_cnt <= 7;
                        mosi <= 1'b1;  // primeiro bit do comando
                        state <= ASSERT;
                    end
                end

                ASSERT: begin
                    sck <= 1;
                    state <= SEND;
                end

                SEND: begin
                    sck <= ~sck;
                    if (sck == 1) begin
                        if (bit_cnt == 0) begin
                            state <= RECV;
                            bit_cnt <= 7;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                            mosi <= tx_buffer[0][bit_cnt - 1];
                        end
                    end
                end

                RECV: begin
                    sck <= ~sck;
                    if (sck == 1) begin
                        rx_shift[bit_cnt] <= miso;
                        if (bit_cnt == 0) begin
                            rx_data[rx_index] <= rx_shift;
                            bit_cnt <= 7;

                            if (rx_index == 3) begin
                                state <= DONE;
                                rx_index <= 0;
                            end
                            else begin
                                rx_index <= rx_index + 1;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                DONE: begin
                    cs_n <= 1;
                    sck  <= 0;
                    done <= ~done;
                    if (done == 0) begin
                        rx_index <= rx_index + 1;
                        id_out <= rx_data[rx_index];

                        if (rx_index == 3) begin
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
