`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UFRN
// Engineer: Gustavo Costa Gomes de Melo
// 
// Create Date: 30.10.2024
// Design Name: PYTHON VM top entity
// Module Name: top
// Project Name: PYTHON VM on FPGA
// Target Devices: BASYS 3 (ARTIX 7)
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
    input CLK,
    input RESET,

    // Buttons
    input BTNR,
    
    // Leds
    output LD0,
    output LD1,
    output LD2,
    output LD3,
    output LD4,
    output LD5,
    output LD6,
    output LD15,
    
    // Diplay 7
    output [7:0] Hex,
    output [3:0] Hex_select,
    
    // USB-UART
    input uart_rx,
    output uart_tx
    ); 
    
    // CLK divider reg
    reg [15:0] clk_div;
    
    // UART wires and regs
    wire uart_read_tick;
    wire uart_write_tick;
    wire rx_full, rx_empty;
    wire [7:0] uart_rec_data;
    wire [7:0] uart_send_data;
    reg [7:0] ticks;

    // display7 wires and regs
    wire [7:0] hex_byte1;

    // Other wires and regs
    wire [4:0] comm_ctrl_state;

    // Opcode FIFO wires and regs
    wire comm_ctrl_fifo_pop;
    wire comm_ctrl_fifo_save;
    wire [7:0] comm_ctrl_opcode;
    wire [7:0] comm_ctrl_arg_type;
    wire [15:0] comm_ctrl_arg_value;
    wire [7:0] comm_ctrl_argval_type;
    wire [7:0] comm_ctrl_argval_len;
    wire [31:0] comm_ctrl_argval_value;
    wire comm_ctrl_fifo_full;
    wire comm_ctrl_fifo_empty;
    wire [31:0] comm_ctrl_print_value;
    wire comm_ctrl_print_empty;
    wire comm_ctrl_print_pop;

    // Python VM wires and regs
    wire [7:0] vm_opcode;
    wire [7:0] vm_arg_type;
    wire [15:0] vm_arg_value;
    wire [7:0] vm_argval_type;
    wire [7:0] vm_argval_len;
    wire [31:0] vm_argval_value;
    wire [1:0] vm_state;
    wire [7:0] vm_debug;
    wire vm_error;
    wire vm_print;
    wire [31:0] vm_print_value;
    wire vm_print_full;

    // Assignments
    assign LD0 = RESET;
    assign LD1 = rx_full;
    assign LD2 = rx_empty;
    assign LD3 = comm_ctrl_fifo_empty;
    assign LD4 = comm_ctrl_fifo_full;
    assign LD5 = comm_ctrl_fifo_save;
    assign LD6 = comm_ctrl_fifo_pop;
    assign LD15 = vm_error;
    
    // Clock divider
        // clk_div[0]  - Frequency = 50 MHz        | Period = 20 ns
        // clk_div[1]  - Frequency = 25 MHz        | Period = 40 ns
        // clk_div[2]  - Frequency = 12.5 MHz      | Period = 80 ns
        // clk_div[3]  - Frequency = 6.25 MHz      | Period = 160 ns
        // clk_div[4]  - Frequency = 3.125 MHz     | Period = 320 ns
        // clk_div[5]  - Frequency = 1.5625 MHz    | Period = 640 ns
        // clk_div[6]  - Frequency = 781.25 kHz    | Period = 1.28 µs
        // clk_div[7]  - Frequency = 390.62 kHz    | Period = 2.56 µs
        // clk_div[8]  - Frequency = 195.31 kHz    | Period = 5.12 µs
        // clk_div[9]  - Frequency = 97.65 kHz     | Period = 10.24 µs
        // clk_div[10] - Frequency = 48.82 kHz     | Period = 20.48 µs
        // clk_div[11] - Frequency = 24.41 kHz     | Period = 40.96 µs
        // clk_div[12] - Frequency = 12.20 kHz     | Period = 81.92 µs
        // clk_div[13] - Frequency = 6.10 kHz      | Period = 163.84 µs
        // clk_div[14] - Frequency = 3.05 kHz      | Period = 327.68 µs
        // clk_div[15] - Frequency = 1.52 kHz      | Period = 655.36 µs
    always @(posedge CLK or posedge RESET) begin
        if (RESET) 
            clk_div <= 0;
        else
            clk_div <= clk_div + 1;
    end

    always @(posedge clk_div[15] or posedge RESET) begin
        if (RESET) begin
            ticks <= 0;
        end
        else begin
            if (uart_read_tick) begin
                ticks <= ticks + 1;
            end
        end
    end
    
    // Seven segmente controller
    display7 d7(
        .clk_1KHz(clk_div[15]),
        .reset(RESET),
        .byte1(hex_byte1),
        .byte2(vm_debug),
        .Hex(Hex),
        .Hex_select(Hex_select)
    );
    
    // Complete UART Core
    uart_unity uart_top (
        .clk_100MHz(CLK),
        .reset(RESET),
        .read_uart(uart_read_tick),
        .write_uart(uart_write_tick),
        .rx(uart_rx),
        .write_data(uart_send_data),
        .rx_full(rx_full),
        .rx_empty(rx_empty),
        .read_data(uart_rec_data),
        .tx(uart_tx)
    );

    // Communication controller
    communication_controller comm_ctrl(
        .CLK(CLK),
        .RESET(RESET),
        .uart_rec_data(uart_rec_data),
        .rx_full(rx_full),
        .rx_empty(rx_empty),
        .fifo_is_full(comm_ctrl_fifo_full),
        .print_fifo_is_empty(comm_ctrl_print_empty),
        .print_value(comm_ctrl_print_value),
        .uart_read_tick(uart_read_tick),
        .uart_write_tick(uart_write_tick),
        .uart_send_data(uart_send_data),
        .state(comm_ctrl_state),
        .debug(hex_byte1),
        .opcode(comm_ctrl_opcode),
        .arg_type(comm_ctrl_arg_type),
        .arg_value(comm_ctrl_arg_value),
        .argval_type(comm_ctrl_argval_type),
        .argval_len(comm_ctrl_argval_len),
        .argval_value(comm_ctrl_argval_value),
        .save_in_fifo(comm_ctrl_fifo_save),
        .print_pop(comm_ctrl_print_pop)
    );

    // Opcode FIFO
    opcode_fifo fifo(
        .CLK(CLK),
        .RESET(RESET),
        .fifo_pop(comm_ctrl_fifo_pop),
        .fifo_save(comm_ctrl_fifo_save),
        .opcode_in(comm_ctrl_opcode),
        .arg_type_in(comm_ctrl_arg_type),
        .arg_value_in(comm_ctrl_arg_value),
        .argval_type_in(comm_ctrl_argval_type),
        .argval_len_in(comm_ctrl_argval_len),
        .argval_in(comm_ctrl_argval_value),
        .fifo_full(comm_ctrl_fifo_full),
        .fifo_empty(comm_ctrl_fifo_empty),
        .opcode_out(vm_opcode),
        .arg_type_out(vm_arg_type),
        .arg_value_out(vm_arg_value),
        .argval_type_out(vm_argval_type),
        .argval_len_out(vm_argval_len),
        .argval_out(vm_argval_value)
    );

    // Python VM
    pyvm vm(
        .CLK(CLK),
        .RESET(RESET),
        .fifo_is_empty(comm_ctrl_fifo_empty),
        .opcode(vm_opcode),
        .arg_type(vm_arg_type),
        .arg_value(vm_arg_value),
        .argval_type(vm_argval_type),
        .argval_len(vm_argval_len),
        .argval_value(vm_argval_value),
        .print_fifo_is_full(vm_print_full),
        .vm_state(vm_state),
        .fifo_pop(comm_ctrl_fifo_pop),
        .debug(vm_debug),
        .error_vm(vm_error),
        .print(vm_print),
        .print_value(vm_print_value)
    );

    print_fifo print_fifo(
        .CLK(CLK),
        .RESET(RESET),
        .fifo_pop(comm_ctrl_print_pop),
        .fifo_save(vm_print),
        .argval_in(vm_print_value),
        .fifo_full(vm_print_full),
        .fifo_empty(comm_ctrl_print_empty),
        .argval_out(comm_ctrl_print_value)
    );
    
endmodule
