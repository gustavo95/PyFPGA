`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2025 09:51:37
// Design Name: 
// Module Name: pyvm
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


module pyvm(
    input CLK,
    input RESET,
    input fifo_is_empty,
    input [7:0] opcode,
    input [7:0] arg_type,
    input [15:0] arg_value,
    input [7:0] argval_type,
    input [7:0] argval_len,
    input [63:0] argval_value,
    input print_fifo_is_full,
    output reg [3:0] vm_state,
    output reg fifo_pop,
    output reg [7:0] debug,
    output reg error_vm,
    output reg print,
    output reg [63:0] print_value
);

    // States
    localparam WAIT_FIFO =  3'd0;
    localparam READ_FIFO =  3'd1;
    localparam PREPARE =    3'd2;
    localparam LOAD_A =     3'd3;
    localparam LOAD_B =     3'd4;
    localparam EXECUTE =    3'd5;
    localparam STORE =      3'd6;
    localparam PRINT =      3'd7;

    //Opcodes
    localparam POP_TOP      = 8'h01;
    localparam PUSH_NULL    = 8'h02;
    localparam STORE_NAME   = 8'h5A;
    localparam LOAD_CONST   = 8'h64;
    localparam LOAD_NAME    = 8'h65;
    localparam BINARY_OP    = 8'h7A;
    localparam RESUME       = 8'h97;
    localparam PRECALL      = 8'hA6;
    localparam CALL         = 8'hAB;

    // Regs
    reg [63:0] stack [7:0];
    reg [7:0] stack_type [8:0];
    reg [7:0] stack_pointer;

    reg [63:0] name_list [8:0];
    reg [7:0] name_list_type [8:0];

    // Auxiliar registers
    reg [31:0] op_a;
    reg [7:0] op_a_type;
    reg [31:0] op_b;
    reg [7:0] op_b_type;
    reg [63:0] op_result;
    reg [7:0] op_result_type;


    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            vm_state <= WAIT_FIFO;
            fifo_pop <= 1'b0;
            debug <= 8'b0;
            error_vm <= 1'b0;
            stack_pointer <= 8'b0;
            print <= 1'b0;
            print_value <= 64'b0;
        end else begin
            case (vm_state)

                // Wait for FIFO to have data
                WAIT_FIFO: begin
                    print <= 1'b0;
                    if (!fifo_is_empty) begin
                        fifo_pop <= 1'b1;
                        vm_state <= READ_FIFO;
                    end
                end

                READ_FIFO: begin
                    // Read FIFO
                    fifo_pop <= 1'b0;
                    vm_state <= PREPARE;
                end

                // Prepare to execute instruction
                PREPARE: begin
                    // Executa instrução
                    case (opcode)
                        POP_TOP: begin
                            debug <= 8'h01;
                            error_vm <= 1'b0;
                            if (stack_pointer > 0) begin
                                stack_pointer <= stack_pointer - 1;
                            end
                            vm_state <= WAIT_FIFO;
                        end
                        PUSH_NULL: begin
                            debug <= 8'h02;
                            error_vm <= 1'b0;
                            stack_pointer <= stack_pointer + 1;
                            vm_state <= EXECUTE;
                        end
                        STORE_NAME: begin
                            debug <= 8'h5A;
                            error_vm <= 1'b0;
                            name_list[arg_value] <= stack[stack_pointer];
                            name_list_type[arg_value] <= stack_type[stack_pointer];
                            stack_pointer <= stack_pointer - 1;
                            vm_state <= WAIT_FIFO;
                        end
                        LOAD_CONST: begin
                            debug <= 8'h64;
                            error_vm <= 1'b0;
                            stack_pointer <= stack_pointer + 1;
                            vm_state <= EXECUTE;
                        end
                        LOAD_NAME: begin
                            debug <= 8'h65;
                            error_vm <= 1'b0;

                            stack_pointer <= stack_pointer + 1;

                            vm_state <= EXECUTE;
                        end
                        BINARY_OP: begin
                            debug <= 8'h7A;
                            error_vm <= 1'b0;
                            vm_state <= LOAD_A;
                        end
                        RESUME: begin
                            debug <= 8'h97;
                            error_vm <= 1'b0;
                            //Do nothing
                            vm_state <= WAIT_FIFO;
                        end
                        PRECALL: begin
                            debug <= 8'hA6;
                            error_vm <= 1'b0;
                            //Do nothing
                            vm_state <= WAIT_FIFO;
                        end
                        CALL: begin
                            debug <= 8'hAB;
                            error_vm <= 1'b0;
                            vm_state <= LOAD_A;
                        end
                        default: begin
                            debug <= 8'hff;
                            error_vm <= 1'b1;
                            vm_state <= WAIT_FIFO;
                        end
                    endcase
                end

                // Load argument A
                LOAD_A: begin
                    op_a <= stack[stack_pointer][31:0];
                    op_a_type <= stack_type[stack_pointer];
                    stack_pointer <= stack_pointer - 1;
                    vm_state <= LOAD_B;
                end

                // Load argument B
                LOAD_B: begin
                    op_b <= stack[stack_pointer][31:0];
                    op_b_type <= stack_type[stack_pointer];
                    stack_pointer <= stack_pointer - 1;
                    vm_state <= EXECUTE;
                end

                // Execute instruction
                EXECUTE: begin
                    case (opcode)
                        PUSH_NULL: begin
                            debug <= 8'h02;
                            error_vm <= 1'b0;
                            stack[stack_pointer] <= 64'b0;
                            stack_type[stack_pointer] <= 8'h00;
                            vm_state <= WAIT_FIFO;
                        end
                        LOAD_CONST: begin
                            // debug <= 8'h64;
                            error_vm <= 1'b0;
                            stack[stack_pointer] <= argval_value;
                            stack_type[stack_pointer] <= argval_type;
                            debug <= argval_value[7:0];
                            vm_state <= WAIT_FIFO;
                        end
                        LOAD_NAME: begin
                            // debug <= 8'h65;
                            error_vm <= 1'b0;

                            if (argval_type == 8'h05) begin
                                stack[stack_pointer] <= argval_value;
                                stack_type[stack_pointer] <= argval_type;
                                debug <= argval_value[7:0];
                            end
                            else if (argval_type == 8'h04) begin
                                stack[stack_pointer] <= name_list[argval_value];
                                stack_type[stack_pointer] <= name_list_type[argval_value];
                                debug <= name_list[argval_value][7:0];
                            end
                            else begin
                                stack[stack_pointer] <= 64'b0;
                                stack_type[stack_pointer] <= 8'h00;
                                debug <= 8'h00;
                                error_vm <= 1'b1;
                            end

                            vm_state <= WAIT_FIFO;
                        end
                        BINARY_OP: begin
                            if (op_a_type == op_b_type) begin
                                op_result_type <= op_a_type;
                                error_vm <= 1'b0;
                                debug <= 8'h7A;
                                case (argval_value)
                                    64'd0: begin
                                        op_result <= op_a + op_b;
                                    end
                                    64'd10: begin
                                        op_result <= op_a - op_b;
                                    end
                                    64'd5: begin
                                        op_result <= op_a * op_b;
                                    end
                                    64'd11: begin
                                        op_result <= op_a / op_b;
                                    end
                                    64'd6: begin
                                        op_result <= op_a % op_b;
                                    end
                                endcase
                                stack_pointer <= stack_pointer + 1;
                                vm_state <= STORE;
                            end else begin 
                                error_vm <= 1'b1;
                                vm_state <= WAIT_FIFO;
                            end
                        end
                        CALL: begin
                            // debug <= 8'hAB;
                            // error_vm <= 1'b0;
                            // vm_state <= PRINT;

                            if (op_b_type == 8'd5) begin
                                if (op_b == 64'd1) begin
                                    debug <= 8'hAB;
                                    vm_state <= PRINT;
                                end
                                else begin
                                    debug <= 8'hfc;
                                    error_vm <= 1'b1;
                                    vm_state <= WAIT_FIFO;
                                end
                            end
                            else begin
                                debug <= 8'hfd;
                                error_vm <= 1'b1;
                                vm_state <= WAIT_FIFO;
                            end
                        end
                    endcase
                end

                // Store result
                STORE: begin
                    stack[stack_pointer] <= op_result;
                    stack_type[stack_pointer] <= op_result_type;
                    debug <= op_result[7:0];
                    vm_state <= WAIT_FIFO;
                end

                // Print instruction
                PRINT: begin
                    if (!print_fifo_is_full) begin
                        print <= 1'b1;
                        print_value <= op_a;
                        // print_value <= 8'haa;
                        vm_state <= WAIT_FIFO;
                    end
                end
            endcase
        end
    end

endmodule
