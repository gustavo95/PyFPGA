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
    input fifo_is_full,
    input print_fifo_is_empty,
    input [63:0] print_value,
    output reg uart_read_tick,
    output reg uart_write_tick,
    output reg [7:0] uart_send_data,
    output reg [4:0] state,
    output reg [7:0] debug,
    output reg [7:0] opcode,
    output reg [7:0] arg_type,
    output reg [15:0] arg_value,
    output reg [7:0] argval_type,
    output reg [7:0] argval_len,
    output reg [63:0] argval_value,
    output reg save_in_fifo,
    output reg print_pop
);

    // States
    localparam WAIT_START_1 = 5'd0;
    localparam WAIT_START_2 = 5'd1;
    localparam REQUEST_BYTECODE = 5'd2;
    localparam READ_OPCODE_1 = 5'd3;
    localparam READ_OPCODE_2 = 5'd4;
    localparam READ_ARG_TYPE_1 = 5'd5;
    localparam READ_ARG_TYPE_2 = 5'd6;
    localparam READ_ARG_B0_1 = 5'd7;
    localparam READ_ARG_B0_2 = 5'd8;
    localparam READ_ARG_B2_1 = 5'd9;
    localparam READ_ARG_B2_2 = 5'd10;
    localparam READ_ARGVAL_TYPE_1 = 5'd11;
    localparam READ_ARGVAL_TYPE_2 = 5'd12;
    localparam READ_ARGVAL_LEN_1 = 5'd13;
    localparam READ_ARGVAL_LEN_2 = 5'd14;
    localparam READ_ARGVAL_1 = 5'd15;
    localparam READ_ARGVAL_2 = 5'd16;
    localparam READ_FIFO = 5'd17;
    localparam PRINT_ARGVAL_1 = 5'd18;
    localparam PRINT_ARGVAL_2 = 5'd19;

    reg [7:0] read_data;
    reg [7:0] argval_len_aux;
    reg [7:0] print_count;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state <= WAIT_START_1;
            uart_read_tick <= 0;
            uart_write_tick <= 0;
            uart_send_data <= 8'b0;
            debug <= 8'b0;
            read_data <= 8'b0;
            argval_len_aux <= 8'b0;
            save_in_fifo <= 1'b0;
            opcode <= 8'b0;
            arg_type <= 8'b0;
            arg_value <= 16'b0;
            argval_type <= 8'b0;
            argval_len <= 8'b0;
            argval_value <= 64'b0;
            print_count <= 8'd7;
            print_pop <= 1'b0;
        end else begin
            case (state)
                WAIT_START_1: begin
                    save_in_fifo <= 1'b0;
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= WAIT_START_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                WAIT_START_2: begin
                    uart_read_tick <= 0;
                    if (read_data == 8'h30) begin
                        state <= REQUEST_BYTECODE;
                    end
                    else begin
                        state <= WAIT_START_1;
                    end
                end
                REQUEST_BYTECODE: begin
                    save_in_fifo <= 1'b0;
                    if (!print_fifo_is_empty) begin
                        print_count <= 8'd7;
                        print_pop <= 1'b1;
                        state <= READ_FIFO;
                    end
                    else if (!fifo_is_full) begin
                        uart_send_data <= 8'h05;
                        uart_write_tick <= 1;
                        state <= READ_OPCODE_1;
                    end
                end
                READ_OPCODE_1: begin
                    uart_write_tick <= 0;
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= READ_OPCODE_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                READ_OPCODE_2: begin
                    uart_read_tick <= 0;
                    debug <= read_data;
                    opcode <= read_data;
                    state <= READ_ARG_TYPE_1;
                end
                READ_ARG_TYPE_1: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= READ_ARG_TYPE_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                READ_ARG_TYPE_2: begin
                    uart_read_tick <= 0;
                    debug <= read_data;
                    arg_type <= read_data;
                    state <= READ_ARG_B0_1;
                end
                READ_ARG_B0_1: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= READ_ARG_B0_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                READ_ARG_B0_2: begin
                    uart_read_tick <= 0;
                    debug <= read_data;
                    arg_value[15:8] <= read_data;
                    state <= READ_ARG_B2_1;
                end
                READ_ARG_B2_1: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= READ_ARG_B2_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                READ_ARG_B2_2: begin
                    uart_read_tick <= 0;
                    debug <= read_data;
                    arg_value[7:0] <= read_data;
                    state <= READ_ARGVAL_TYPE_1;
                end
                READ_ARGVAL_TYPE_1: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= READ_ARGVAL_TYPE_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                READ_ARGVAL_TYPE_2: begin
                    uart_read_tick <= 0;
                    debug <= read_data;
                    argval_type <= read_data;
                    state <= READ_ARGVAL_LEN_1;
                end
                READ_ARGVAL_LEN_1: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        uart_read_tick <= 1;
                        state <= READ_ARGVAL_LEN_2;
                    end else begin
                        uart_read_tick <= 0;
                    end
                end
                READ_ARGVAL_LEN_2: begin
                    uart_read_tick <= 0;
                    debug <= read_data;
                    argval_len <= read_data;
                    argval_len_aux <= read_data;
                    state <= READ_ARGVAL_1;
                end
                READ_ARGVAL_1: begin
                    if (!rx_empty) begin
                        read_data <= uart_rec_data;
                        argval_len_aux <= argval_len_aux - 1'b1;
                        uart_read_tick <= 1'b1;
                        state <= READ_ARGVAL_2;
                    end else begin
                        uart_read_tick <= 1'b0;
                    end
                end
                READ_ARGVAL_2: begin
                    uart_read_tick <= 1'b0;
                    debug <= read_data;
                    argval_value[(argval_len_aux << 3) +: 8] <= read_data;
                    if (argval_len_aux <= 8'b0) begin
                        save_in_fifo <= 1'b1;
                        state <= REQUEST_BYTECODE;
                    end else begin
                        state <= READ_ARGVAL_1;
                    end
                end
                READ_FIFO: begin
                    print_pop <= 1'b0;
                    state <= PRINT_ARGVAL_1;
                    // print_count <= print_count - 1'b1;
                end
                PRINT_ARGVAL_1: begin
                    print_pop <= 1'b0;
                    uart_send_data <= print_value[(print_count << 3) +: 8];
                    // uart_send_data <= print_value[7:0];
                    print_count <= print_count - 1'b1;
                    uart_write_tick <= 1'b1;
                    state <= PRINT_ARGVAL_2;
                end
                PRINT_ARGVAL_2: begin
                    uart_write_tick <= 1'b0;
                    debug <= print_count;
                    if (print_count <= 8'd0) begin
                        state <= REQUEST_BYTECODE;
                    end else begin
                        state <= PRINT_ARGVAL_1;
                    end
                end

                // WAIT_CODE: begin
                //     if (!rx_empty) begin
                //         read_data <= uart_rec_data;
                //         uart_read_tick <= 1;
                //         state <= SAVE_CODE;
                //     end else begin
                //         uart_read_tick <= 0;
                //     end
                // end
                // SAVE_CODE: begin
                //     uart_read_tick <= 0;
                //     if (read_data == 8'h30) begin
                //         state <= WAIT_COMMAND;
                //     end else begin
                //         debug <= read_data;
                //         state <= WAIT_CODE;
                //     end
                // end
                // default: state <= WAIT_CODE;
            endcase
        end
    end
    

endmodule
