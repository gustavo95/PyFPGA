`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 14:13:20
// Design Name: 
// Module Name: testbench
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

`timescale 1ns/1ps

module tb_mem_data;
    localparam PAGE_WORDS = 16;
    localparam NUM_PAGES  = 32;

    reg clk;
    reg rst;

    // ---------- ALLOC ----------
    reg        i_alloc_start;
    reg [4:0]  i_alloc_len;
    reg [4:0]  i_alloc_epoch;
    wire       o_alloc_ready;
    wire       o_alloc_done;
    wire       o_alloc_ok;
    wire [8:0] o_alloc_ptr;

    // ---------- WRITE PAYLOAD ----------
    reg        i_wr_start;
    reg [8:0]  i_wr_ptr;
    reg [4:0]  i_wr_len;
    reg [31:0] i_wr_data;
    wire       o_wr_ready;
    wire       o_wr_done;
    wire       o_wr_ok;

    // ---------- READ PAYLOAD / STREAM ----------
    reg        i_rd_start;
    reg [9:0]  i_rd_ptr;
    reg [4:0]  i_rd_len;
    wire [31:0] o_rd_data;
    wire       o_rd_ready;
    wire [4:0] o_rd_idx;
    wire       o_rd_done;
    wire       o_rd_ok;
    wire       o_rd_tick;

    mem_data #(
        .PAGE_WORDS(PAGE_WORDS),
        .NUM_PAGES(NUM_PAGES)
    ) dut (
        .clk(clk),
        .rst(rst),

        .i_alloc_start(i_alloc_start),
        .i_alloc_len(i_alloc_len),
        .i_alloc_epoch(i_alloc_epoch),
        .o_alloc_ready(o_alloc_ready),
        .o_alloc_done(o_alloc_done),
        .o_alloc_ok(o_alloc_ok),
        .o_alloc_ptr(o_alloc_ptr),

        .i_wr_start(i_wr_start),
        .i_wr_ptr(i_wr_ptr),
        .i_wr_len(i_wr_len),
        .i_wr_data(i_wr_data),
        .o_wr_ready(o_wr_ready),
        .o_wr_done(o_wr_done),
        .o_wr_ok(o_wr_ok),

        .i_rd_start(i_rd_start),
        .i_rd_ptr(i_rd_ptr),
        .i_rd_len(i_rd_len),
        .o_rd_data(o_rd_data),
        .o_rd_ready(o_rd_ready),
        .o_rd_idx(o_rd_idx),
        .o_rd_done(o_rd_done),
        .o_rd_ok(o_rd_ok),
        .o_rd_tick(o_rd_tick)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk;

    task do_alloc;
        input [4:0] len;
        input [4:0] epoch;
        begin
            @(posedge clk);
            i_alloc_len   <= len;
            i_alloc_epoch <= epoch;
            i_alloc_start <= 1'b1;

            @(posedge clk);
            i_alloc_start <= 1'b0;

            wait(o_alloc_done == 1'b1);

            $display("time=%0t len=%0d epoch=%0d ok=%0d ptr=%0d",
                     $time, len, epoch, o_alloc_ok, o_alloc_ptr);

            @(posedge clk);
        end
    endtask

    task do_read;
        input [8:0] ptr;
        input [4:0] len;
        begin
            @(posedge clk);
            i_rd_ptr   <= ptr;
            i_rd_len   <= len;
            i_rd_start <= 1'b1;

            @(posedge clk);
            i_rd_start <= 1'b0;

            wait(o_rd_done == 1'b1);

            $display("time=%0t ptr=%0d len=%0d ok=%0d",
                     $time, ptr, len, o_rd_ok);

            @(posedge clk);
        end
    endtask

    initial begin
        // defaults
        rst = 1'b1;

        i_alloc_start = 1'b0;
        i_alloc_len   = 5'd0;
        i_alloc_epoch = 5'd0;

        i_wr_start = 1'b0;
        i_wr_ptr   = 9'd0;
        i_wr_len   = 5'd0;
        i_wr_data  = 32'd0;

        i_rd_start = 1'b0;
        i_rd_ptr   = 10'd0;
        i_rd_len   = 5'd0;

        repeat(3) @(posedge clk);
        rst = 1'b0;

        // testes alloc
        // do_alloc(5'd3, 5'd2);   // espera ptr 0
        // do_alloc(5'd4, 5'd2);   // espera ptr 3
        // do_alloc(5'd10, 5'd2);  // deve ir para próxima página
        // do_alloc(5'd2, 5'd1);   // depende da tua regra de epoch
        // do_alloc(5'd0, 5'd2);   // inválido
        // do_alloc(5'd17, 5'd2);  // inválido

        // do_alloc(5'd1, 5'd0); // aloca 1 global, ptr 0
        // do_alloc(5'd1, 5'd0); // aloca 1 global, ptr 1
        // do_alloc(5'd1, 5'd1); // aloca 1 local, ptr 10
        // do_alloc(5'd2, 5'd1); // aloca 2 local, ptr 11
        // do_alloc(5'd1, 5'd0); // aloca 1 global, ptr 2
        // do_alloc(5'd1, 5'd1); // aloca 1 local, ptr 13
        // do_alloc(5'd1, 5'd2); // aloca 1 epoch 2, ptr 20
        // do_alloc(5'd15, 5'd1); // aloca 15 local, ptr 20

        // testes read
        do_read(9'd0, 5'd2);

        repeat(10) @(posedge clk);
        $finish;
    end

endmodule