`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.03.2026 09:42:36
// Design Name: 
// Module Name: tb_mem_object
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


`timescale 1ns / 1ps

module tb_mem_object;

    // -------------------------
    // Parameters
    // -------------------------
    localparam NUM_VAR = 512;

    // -------------------------
    // DUT signals
    // -------------------------
    reg         clk;
    reg         rst;

    // ALLOC
    reg         i_alloc_start;
    reg  [4:0]  i_alloc_epoch;
    wire        o_alloc_ready;
    wire        o_alloc_done;
    wire        o_alloc_ok;
    wire [8:0]  o_alloc_idx;

    // WRITE
    reg         i_write_en;
    reg  [8:0]  i_write_addr;
    reg  [7:0]  i_write_type;
    reg  [4:0]  i_write_len;
    reg  [8:0]  i_write_ptr;

    // READ
    reg  [8:0]  i_read_addr;
    wire [7:0]  o_read_type;
    wire [4:0]  o_read_len;
    wire [8:0]  o_read_ptr;

    // -------------------------
    // Instantiate DUT
    // -------------------------
    mem_object #(
        .NUM_VAR(NUM_VAR)
    ) dut (
        .clk(clk),
        .rst(rst),

        .i_alloc_start(i_alloc_start),
        .i_alloc_epoch(i_alloc_epoch),
        .o_alloc_ready(o_alloc_ready),
        .o_alloc_done(o_alloc_done),
        .o_alloc_ok(o_alloc_ok),
        .o_alloc_idx(o_alloc_idx),

        .i_write_en(i_write_en),
        .i_write_addr(i_write_addr),
        .i_write_type(i_write_type),
        .i_write_len(i_write_len),
        .i_write_ptr(i_write_ptr),

        .i_read_addr(i_read_addr),
        .o_read_type(o_read_type),
        .o_read_len(o_read_len),
        .o_read_ptr(o_read_ptr)
    );

    // -------------------------
    // Clock generation
    // -------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // -------------------------
    // Tasks
    // -------------------------
    task do_reset;
    begin
        rst = 1;
        i_alloc_start = 0;
        i_alloc_epoch = 0;
        i_write_en    = 0;
        i_write_addr  = 0;
        i_write_type  = 0;
        i_write_len   = 0;
        i_write_ptr   = 0;
        i_read_addr   = 0;

        repeat (3) @(posedge clk);
        rst = 0;
        @(posedge clk);
    end
    endtask

    task do_alloc(input [4:0] epoch);
    begin
        @(posedge clk);
        while (!o_alloc_ready)
            @(posedge clk);

        i_alloc_epoch <= epoch;
        i_alloc_start <= 1'b1;

        @(posedge clk);
        i_alloc_start <= 1'b0;

        while (!o_alloc_done)
            @(posedge clk);

        $display("[%0t] ALLOC epoch=%0d -> done=%0b ok=%0b idx=%0d",
                 $time, epoch, o_alloc_done, o_alloc_ok, o_alloc_idx);
    end
    endtask

    task do_write(
        input [8:0] addr,
        input [7:0] typ,
        input [4:0] len,
        input [8:0] ptr
    );
    begin
        @(posedge clk);
        i_write_addr <= addr;
        i_write_type <= typ;
        i_write_len  <= len;
        i_write_ptr  <= ptr;
        i_write_en   <= 1'b1;

        @(posedge clk);
        i_write_en   <= 1'b0;

        $display("[%0t] WRITE addr=%0d type=%0d len=%0d ptr=%0d",
                 $time, addr, typ, len, ptr);
    end
    endtask

    task do_read(input [8:0] addr);
    begin
        @(posedge clk);
        i_read_addr <= addr;

        // como a leitura é síncrona, espera 1 ciclo para saída atualizar
        @(posedge clk);

        $display("[%0t] READ  addr=%0d -> type=%0d len=%0d ptr=%0d",
                 $time, addr, o_read_type, o_read_len, o_read_ptr);
    end
    endtask

    // -------------------------
    // Test sequence
    // -------------------------
    initial begin
        $display("=== TB mem_object start ===");

        do_reset();

        // leitura inicial
        do_read(9'd0);

        // primeira alocação: após reset, todos epoch=31
        // epoch 5 deve alocar no índice 0
        do_alloc(5'd5);

        // escreve dados no índice alocado
        do_write(o_alloc_idx, 8'h11, 5'd4, 9'd33);
        do_read(o_alloc_idx);

        // segunda alocação com epoch maior
        // índice 0 agora tem epoch=5, então não pode sobrescrever
        // deve ir para índice 1
        do_alloc(5'd6);
        do_write(o_alloc_idx, 8'h22, 5'd2, 9'd99);
        do_read(o_alloc_idx);

        // terceira alocação com epoch menor
        // como epoch menor tem prioridade, pode reutilizar índice 0
        do_alloc(5'd3);
        do_write(o_alloc_idx, 8'h33, 5'd7, 9'd123);
        do_read(o_alloc_idx);

        // lê alguns índices para conferir
        do_read(9'd0);
        do_read(9'd1);
        do_read(9'd2);

        $display("=== TB mem_object end ===");
        #20;
        $finish;
    end

endmodule