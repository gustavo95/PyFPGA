`timescale 1ns / 1ps

module mem_heap(
    input wire clk,
    input wire rst,

    // ---------- ALLOC ----------
    input wire i_alloc_start,
    input wire [4:0] i_alloc_epoch,
    input wire [7:0] i_alloc_type,
    input wire [4:0] i_alloc_len,
    output reg o_alloc_ready,
    output reg o_alloc_done,
    output reg o_alloc_ok,
    output reg [8:0] o_alloc_idx,
    output reg o_alloc_exception,

    // ---------- WRITE ----------
    input wire i_write_start,
    input wire [8:0] i_write_idx,
    input wire [31:0] i_write_data,
    input wire i_write_tick,
    output reg o_write_ready,
    output reg o_write_done,
    output reg o_write_ok,
    output reg o_write_exception,

    // ---------- READ ----------
    input wire i_read_start,
    input wire [8:0] i_read_idx,
    output reg [7:0] o_read_type,
    output reg [31:0] o_read_data,
    output reg o_read_ready,
    output reg o_read_tick,
    output reg o_read_done,
    output reg o_read_ok,
    output reg o_read_exception
);

    // ---------- MEMORY OBJECT SIGNALS ----------
    reg        r_obj_alloc_start;
    reg [4:0]  r_obj_alloc_epoch;
    wire       w_obj_alloc_ready;
    wire       w_obj_alloc_done;
    wire       w_obj_alloc_ok;
    wire [8:0] w_obj_alloc_idx;

    reg        r_obj_write_en;
    reg [8:0]  r_obj_write_idx;
    reg [7:0]  r_obj_write_type;
    reg [4:0]  r_obj_write_len;
    reg [8:0]  r_obj_write_ptr;

    reg  [8:0] r_obj_read_idx;
    wire [7:0] w_obj_read_type;
    wire [4:0] w_obj_read_len;
    wire [8:0] w_obj_read_ptr;
    wire [4:0] w_obj_read_epoch;

    // ---------- MEMORY DATA SIGNALS ----------
    reg        r_data_alloc_start;
    reg [4:0]  r_data_alloc_len;
    reg [4:0]  r_data_alloc_epoch;
    wire       w_data_alloc_ready;
    wire       w_data_alloc_done;
    wire       w_data_alloc_ok;
    wire [8:0] w_data_alloc_ptr;

    reg        r_data_write_start;
    reg [8:0]  r_data_write_ptr;
    reg [4:0]  r_data_write_len;
    reg [31:0] r_data_write_data;
    reg        r_data_write_tick;
    wire       w_data_write_ready;
    wire       w_data_write_done;
    wire       w_data_write_ok;

    reg        r_data_read_start;
    reg [8:0]  r_data_read_ptr;
    reg [4:0]  r_data_read_len;
    wire [31:0] w_data_read_data;
    wire        w_data_read_ready;
    wire [4:0]  w_data_read_idx;
    wire        w_data_read_done;
    wire        w_data_read_ok;
    wire        w_data_read_tick;

    // ---------- ALLOC FSM ----------
    localparam A_IDLE      = 3'd0,
               A_WAIT_OBJ  = 3'd1,
               A_ALLOC_OBJ = 3'd2,
               A_WAIT_DATA = 3'd3,
               A_ALLOC_DATA= 3'd4,
               A_WRITE_OBJ = 3'd5,
               A_DONE      = 3'd6;

    reg [2:0] a_state;
    reg [4:0] a_epoch;
    reg [7:0] a_type;
    reg [4:0] a_len;
    reg [8:0] a_idx;
    reg [8:0] a_ptr;

    // ---------- MEM_OBJECT READ FSM ----------
    // Agora precisa esperar a latência da BRAM do mem_object
    localparam RO_IDLE      = 4'd0,
               RO_SET_RD    = 4'd1,
               RO_WAIT_RD_0 = 4'd2,
               RO_WAIT_RD_1 = 4'd3,
               RO_DONE_RD   = 4'd4,
               RO_SET_WR    = 4'd5,
               RO_WAIT_WR_0 = 4'd6,
               RO_WAIT_WR_1 = 4'd7,
               RO_DONE_WR   = 4'd8;

    reg [3:0] rmo_state;
    reg       rmo_ready;

    reg       rmo_rd_start;
    reg [8:0] rmo_rd_idx;
    reg       rmo_rd_done;
    reg [7:0] rmo_rd_type;
    reg [4:0] rmo_rd_len;
    reg [8:0] rmo_rd_ptr;
    reg [4:0] rmo_rd_epoch;

    reg       rmo_wr_start;
    reg [8:0] rmo_wr_idx;
    reg       rmo_wr_done;
    reg [7:0] rmo_wr_type;
    reg [4:0] rmo_wr_len;
    reg [8:0] rmo_wr_ptr;
    reg [4:0] rmo_wr_epoch;

    // ---------- WRITE FSM ----------
    localparam W_IDLE       = 3'd0,
               W_WAIT_READY = 3'd1,
               W_READ_OBJ   = 3'd2,
               W_WAIT_DATA  = 3'd3,
               W_WRITE_DATA = 3'd4,
               W_NEXT_WRITE = 3'd5;

    reg [2:0] w_state;
    reg [8:0] w_idx;
    reg [4:0] w_len;
    reg [8:0] w_ptr;

    // ---------- READ FSM ----------
    localparam R_IDLE       = 3'd0,
               R_WAIT_READY = 3'd1,
               R_READ_OBJ   = 3'd2,
               R_WAIT_DATA  = 3'd3,
               R_READ_DATA  = 3'd4;

    reg [2:0] r_state;
    reg [8:0] r_idx;
    reg [4:0] r_len;
    reg [8:0] r_ptr;

    // ---------- ALLOC IMPLEMENTATION ----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_state           <= A_IDLE;
            r_obj_alloc_start <= 0;
            r_obj_alloc_epoch <= 0;
            r_obj_write_en    <= 0;
            r_obj_write_idx   <= 0;
            r_obj_write_type  <= 0;
            r_obj_write_len   <= 0;
            r_obj_write_ptr   <= 0;
            r_data_alloc_start<= 0;
            r_data_alloc_len  <= 0;
            r_data_alloc_epoch<= 0;
            o_alloc_ready     <= 0;
            o_alloc_done      <= 0;
            o_alloc_ok        <= 0;
            o_alloc_idx       <= 0;
            o_alloc_exception <= 0;
        end else begin
            case (a_state)
                A_IDLE: begin
                    o_alloc_ok        <= 0;
                    o_alloc_done      <= 0;
                    r_obj_alloc_start <= 0;
                    r_data_alloc_start<= 0;
                    r_obj_write_en    <= 0;

                    if (i_alloc_start) begin
                        a_epoch       <= i_alloc_epoch;
                        a_type        <= i_alloc_type;
                        a_len         <= i_alloc_len;
                        o_alloc_ready <= 0;
                        a_state       <= A_WAIT_OBJ;
                    end else begin
                        o_alloc_ready <= 1;
                    end
                end

                A_WAIT_OBJ: begin
                    if (w_obj_alloc_ready) begin
                        r_obj_alloc_epoch <= a_epoch;
                        r_obj_alloc_start <= 1;
                        a_state           <= A_ALLOC_OBJ;
                    end
                end

                A_ALLOC_OBJ: begin
                    r_obj_alloc_start <= 0;
                    if (w_obj_alloc_done) begin
                        if (w_obj_alloc_ok) begin
                            a_idx   <= w_obj_alloc_idx;
                            a_state <= A_WAIT_DATA;
                        end else begin
                            o_alloc_done      <= 1;
                            o_alloc_exception <= 1;
                            a_state           <= A_IDLE;
                        end
                    end
                end

                A_WAIT_DATA: begin
                    if (w_data_alloc_ready) begin
                        r_data_alloc_len   <= a_len;
                        r_data_alloc_epoch <= a_epoch;
                        r_data_alloc_start <= 1;
                        a_state            <= A_ALLOC_DATA;
                    end
                end

                A_ALLOC_DATA: begin
                    r_data_alloc_start <= 0;
                    if (w_data_alloc_done) begin
                        if (w_data_alloc_ok) begin
                            a_ptr   <= w_data_alloc_ptr;
                            a_state <= A_WRITE_OBJ;
                        end else begin
                            o_alloc_done      <= 1;
                            o_alloc_exception <= 1;
                            a_state           <= A_IDLE;
                        end
                    end
                end

                A_WRITE_OBJ: begin
                    r_obj_write_idx  <= a_idx;
                    r_obj_write_type <= a_type;
                    r_obj_write_len  <= a_len;
                    r_obj_write_ptr  <= a_ptr;
                    r_obj_write_en   <= 1;
                    a_state          <= A_DONE;
                end

                A_DONE: begin
                    r_obj_write_en <= 0;
                    o_alloc_ok     <= 1;
                    o_alloc_done   <= 1;
                    o_alloc_idx    <= a_idx;
                    a_state        <= A_IDLE;
                end
            endcase
        end
    end

    // ---------- MEM_OBJECT READ IMPLEMENTATION ----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rmo_state    <= RO_IDLE;
            rmo_ready    <= 0;

            rmo_rd_done  <= 0;
            rmo_rd_type  <= 0;
            rmo_rd_len   <= 0;
            rmo_rd_ptr   <= 0;
            rmo_rd_epoch <= 0;

            rmo_wr_done  <= 0;
            rmo_wr_type  <= 0;
            rmo_wr_len   <= 0;
            rmo_wr_ptr   <= 0;
            rmo_wr_epoch <= 0;

            r_obj_read_idx <= 0;
        end else begin
            case (rmo_state)
                RO_IDLE: begin
                    rmo_rd_done <= 0;
                    rmo_wr_done <= 0;

                    if (rmo_rd_start) begin
                        rmo_ready <= 0;
                        rmo_state <= RO_SET_RD;
                    end else if (rmo_wr_start) begin
                        rmo_ready <= 0;
                        rmo_state <= RO_SET_WR;
                    end else begin
                        rmo_ready <= 1;
                    end
                end

                RO_SET_RD: begin
                    r_obj_read_idx <= rmo_rd_idx;
                    rmo_state      <= RO_WAIT_RD_0;
                end
                RO_WAIT_RD_0: begin
                    rmo_state <= RO_WAIT_RD_1;
                end
                RO_WAIT_RD_1: begin
                    rmo_state <= RO_DONE_RD;
                end
                RO_DONE_RD: begin
                    rmo_rd_done  <= 1;
                    rmo_rd_type  <= w_obj_read_type;
                    rmo_rd_len   <= w_obj_read_len;
                    rmo_rd_ptr   <= w_obj_read_ptr;
                    rmo_rd_epoch <= w_obj_read_epoch;
                    rmo_state    <= RO_IDLE;
                end

                RO_SET_WR: begin
                    r_obj_read_idx <= rmo_wr_idx;
                    rmo_state      <= RO_WAIT_WR_0;
                end
                RO_WAIT_WR_0: begin
                    rmo_state <= RO_WAIT_WR_1;
                end
                RO_WAIT_WR_1: begin
                    rmo_state <= RO_DONE_WR;
                end
                RO_DONE_WR: begin
                    rmo_wr_done  <= 1;
                    rmo_wr_type  <= w_obj_read_type;
                    rmo_wr_len   <= w_obj_read_len;
                    rmo_wr_ptr   <= w_obj_read_ptr;
                    rmo_wr_epoch <= w_obj_read_epoch;
                    rmo_state    <= RO_IDLE;
                end

                default: begin
                    rmo_state <= RO_IDLE;
                end
            endcase
        end
    end

    // ---------- WRITE IMPLEMENTATION ----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            w_state            <= W_IDLE;
            r_data_write_start <= 0;
            r_data_write_ptr   <= 0;
            r_data_write_len   <= 0;
            r_data_write_data  <= 0;
            r_data_write_tick  <= 0;
            o_write_ready      <= 0;
            o_write_done       <= 0;
            o_write_ok         <= 0;
            o_write_exception  <= 0;
            rmo_wr_start       <= 0;
            rmo_wr_idx         <= 0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    o_write_ok         <= 0;
                    o_write_done       <= 0;
                    r_data_write_start <= 0;
                    r_data_write_tick  <= 0;
                    rmo_wr_start       <= 0;

                    if (i_write_start) begin
                        w_idx         <= i_write_idx;
                        o_write_ready <= 0;
                        w_state       <= W_WAIT_READY;
                    end else begin
                        o_write_ready <= 1;
                    end
                end

                W_WAIT_READY: begin
                    if (rmo_ready) begin
                        rmo_wr_idx   <= w_idx;
                        rmo_wr_start <= 1;
                        w_state      <= W_READ_OBJ;
                    end
                end

                W_READ_OBJ: begin
                    rmo_wr_start <= 0;
                    if (rmo_wr_done) begin
                        if (rmo_wr_type == 0) begin
                            o_write_done      <= 1;
                            o_write_exception <= 1;
                            w_state           <= W_IDLE;
                        end else begin
                            w_len   <= rmo_wr_len;
                            w_ptr   <= rmo_wr_ptr;
                            w_state <= W_WAIT_DATA;
                        end
                    end
                end

                W_WAIT_DATA: begin
                    if (w_data_write_ready) begin
                        r_data_write_ptr   <= w_ptr;
                        r_data_write_len   <= w_len;
                        r_data_write_start <= 1;
                        w_state            <= W_WRITE_DATA;
                    end
                end

                W_WRITE_DATA: begin
                    r_data_write_start <= 0;
                    o_write_ok         <= 0;

                    if (w_data_write_done) begin
                        o_write_done <= 1;
                        w_state      <= W_IDLE;
                        if (!w_data_write_ok)
                            o_write_exception <= 1;
                        else
                            o_write_ok        <= 1;
                    end else if (!w_data_write_ok && i_write_tick) begin
                        r_data_write_data <= i_write_data;
                        r_data_write_tick <= 1;
                        w_state           <= W_NEXT_WRITE;
                    end
                end

                W_NEXT_WRITE: begin
                    if (w_data_write_done) begin
                        o_write_done      <= 1;
                        r_data_write_tick <= 0;
                        w_state           <= W_IDLE;
                        if (!w_data_write_ok) begin
                            o_write_exception <= 1;
                            o_write_ok        <= 0;
                        end else begin
                            o_write_ok <= 1;
                        end
                    end else begin
                        if (w_data_write_ok) begin
                            r_data_write_tick <= 0;
                            o_write_ok        <= 1;
                        end
                        if (!i_write_tick)
                            w_state <= W_WRITE_DATA;
                    end
                end
            endcase
        end
    end

    // ---------- READ IMPLEMENTATION ----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_state            <= R_IDLE;
            rmo_rd_start       <= 0;
            r_data_read_start  <= 0;
            r_data_read_ptr    <= 0;
            o_read_ready       <= 0;
            o_read_done        <= 0;
            o_read_ok          <= 0;
            o_read_tick        <= 0;
            rmo_rd_idx         <= 0;
            o_read_exception   <= 0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    o_read_ok        <= 0;
                    o_read_done      <= 0;
                    o_read_tick      <= 0;
                    r_data_read_start<= 0;
                    rmo_rd_start     <= 0;

                    if (i_read_start) begin
                        o_read_ready <= 0;
                        r_idx        <= i_read_idx;
                        r_state      <= R_WAIT_READY;
                    end else begin
                        o_read_ready <= 1;
                    end
                end

                R_WAIT_READY: begin
                    if (rmo_ready) begin
                        rmo_rd_idx   <= r_idx;
                        rmo_rd_start <= 1;
                        r_state      <= R_READ_OBJ;
                    end
                end

                R_READ_OBJ: begin
                    rmo_rd_start <= 0;
                    if (rmo_rd_done) begin
                        if (rmo_rd_type == 0) begin
                            o_read_done      <= 1;
                            o_read_exception <= 1;
                            r_state          <= R_IDLE;
                        end else begin
                            o_read_type <= rmo_rd_type;
                            r_len       <= rmo_rd_len;
                            r_ptr       <= rmo_rd_ptr;
                            r_state     <= R_WAIT_DATA;
                        end
                    end
                end

                R_WAIT_DATA: begin
                    if (w_data_read_ready) begin
                        r_data_read_ptr   <= r_ptr;
                        r_data_read_len   <= r_len;
                        r_data_read_start <= 1;
                        r_state           <= R_READ_DATA;
                    end
                end

                R_READ_DATA: begin
                    r_data_read_start <= 0;

                    if (w_data_read_tick) begin
                        o_read_data <= w_data_read_data;
                        o_read_ok   <= w_data_read_ok;
                        o_read_tick <= 1;
                        if (!w_data_read_ok)
                            o_read_exception <= 1;
                    end else begin
                        o_read_tick <= 0;
                    end

                    if (w_data_read_done) begin
                        o_read_done <= 1;
                        r_state     <= R_IDLE;
                    end
                end
            endcase
        end
    end

    // ---------- INSTANTIATE MEMORY OBJECT ----------
    mem_object #(
        .NUM_VAR(512)
    ) mem_obj_inst (
        .clk(clk),
        .rst(rst),

        .i_alloc_start(r_obj_alloc_start),
        .i_alloc_epoch(r_obj_alloc_epoch),
        .o_alloc_ready(w_obj_alloc_ready),
        .o_alloc_done(w_obj_alloc_done),
        .o_alloc_ok(w_obj_alloc_ok),
        .o_alloc_idx(w_obj_alloc_idx),

        .i_wr_en(r_obj_write_en),
        .i_wr_idx(r_obj_write_idx),
        .i_wr_type(r_obj_write_type),
        .i_wr_len(r_obj_write_len),
        .i_wr_ptr(r_obj_write_ptr),

        .i_rd_idx(r_obj_read_idx),
        .o_rd_type(w_obj_read_type),
        .o_rd_len(w_obj_read_len),
        .o_rd_ptr(w_obj_read_ptr),
        .o_rd_epoch(w_obj_read_epoch)
    );

    // ---------- INSTANTIATE MEMORY DATA ----------
    mem_data #(
        .PAGE_WORDS(16),
        .NUM_PAGES(32)
    ) mem_data_inst (
        .clk(clk),
        .rst(rst),
        .i_alloc_start(r_data_alloc_start),
        .i_alloc_len(r_data_alloc_len),
        .i_alloc_epoch(r_data_alloc_epoch),
        .o_alloc_ready(w_data_alloc_ready),
        .o_alloc_done(w_data_alloc_done),
        .o_alloc_ok(w_data_alloc_ok),
        .o_alloc_ptr(w_data_alloc_ptr),
        .i_wr_start(r_data_write_start),
        .i_wr_ptr(r_data_write_ptr),
        .i_wr_len(r_data_write_len),
        .i_wr_data(r_data_write_data),
        .i_wr_tick(r_data_write_tick),
        .o_wr_ready(w_data_write_ready),
        .o_wr_done(w_data_write_done),
        .o_wr_ok(w_data_write_ok),
        .i_rd_start(r_data_read_start),
        .i_rd_ptr(r_data_read_ptr),
        .i_rd_len(r_data_read_len),
        .o_rd_data(w_data_read_data),
        .o_rd_ready(w_data_read_ready),
        .o_rd_idx(w_data_read_idx),
        .o_rd_done(w_data_read_done),
        .o_rd_ok(w_data_read_ok),
        .o_rd_tick(w_data_read_tick)
    );
endmodule
