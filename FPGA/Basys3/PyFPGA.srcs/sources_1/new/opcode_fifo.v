module opcode_fifo(
    input CLK,
    input RESET,
    input fifo_pop,
    input fifo_save,
    input [7:0] opcode_in,
    input [7:0] oparg_type_in,
    input [15:0] oparg_in,
    input [7:0] argval_type_in,
    input [7:0] argval_len_in,
    input [31:0] argval_in,
    output fifo_full,
    output fifo_empty,
    output reg [7:0] opcode_out,
    output reg [7:0] oparg_type_out,
    output reg [15:0] oparg_out,
    output reg [7:0] argval_type_out,
    output reg [7:0] argval_len_out,
    output reg [31:0] argval_out
);

    // FIFO interna achatada
    reg [7:0] fifo_opcode [3:0];
    reg [7:0] fifo_oparg_type [3:0];
    reg [15:0] fifo_oparg [3:0];
    reg [7:0] fifo_argval_type [3:0];
    reg [7:0] fifo_argval_len [3:0];
    reg [31:0] fifo_argval [3:0];

    // Controle
    reg [1:0] read_ptr, write_ptr;
    reg [3:0] fifo_count;

    assign fifo_full = (fifo_count == 4'd4);
    assign fifo_empty = (fifo_count == 4'd0);

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            fifo_count <= 4'd0;
            read_ptr <= 4'd0;
            write_ptr <= 4'd0;
        end else begin
            if (fifo_save && !fifo_full) begin
                // Salvar na FIFO
                fifo_opcode[write_ptr] <= opcode_in;
                fifo_oparg_type[write_ptr] <= oparg_type_in;
                fifo_oparg[write_ptr] <= oparg_in;
                fifo_argval_type[write_ptr] <= argval_type_in;
                fifo_argval_len[write_ptr] <= argval_len_in;
                fifo_argval[write_ptr] <= argval_in;

                write_ptr <= write_ptr + 3'd1;
                fifo_count <= fifo_count + 4'd1;
            end
            else if (fifo_pop && !fifo_empty) begin
                // Ler da FIFO
                opcode_out <= fifo_opcode[read_ptr];
                oparg_type_out <= fifo_arg_type[read_ptr];
                oparg_out <= fifo_oparg[read_ptr];
                argval_type_out <= fifo_argval_type[read_ptr];
                argval_len_out <= fifo_argval_len[read_ptr];
                argval_out <= fifo_argval[read_ptr];

                read_ptr <= read_ptr + 3'd1;
                fifo_count <= fifo_count - 4'd1;
            end

        end
    end
endmodule
