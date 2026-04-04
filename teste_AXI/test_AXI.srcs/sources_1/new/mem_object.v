`timescale 1ns / 1ps

module mem_object #(
    parameter NUM_VAR = 512
)(
    input  wire        clk,
    input  wire        rst,

    // ---------- ALLOC ----------
    input  wire        i_alloc_start,
    input  wire [4:0]  i_alloc_epoch,
    output reg         o_alloc_ready,
    output reg         o_alloc_done,
    output reg         o_alloc_ok,
    output reg  [8:0]  o_alloc_idx,

    // ---------- WRITE ----------
    input  wire        i_wr_en,
    input  wire [8:0]  i_wr_idx,
    input  wire [7:0]  i_wr_type,
    input  wire [4:0]  i_wr_len,
    input  wire [8:0]  i_wr_ptr,

    // ---------- READ ----------
    input  wire [8:0]  i_rd_idx,
    output reg  [7:0]  o_rd_type,
    output reg  [4:0]  o_rd_len,
    output reg  [8:0]  o_rd_ptr,
    output reg  [4:0]  o_rd_epoch
);

    // ============================================================
    // BRAM word layout
    // [31:27] epoch
    // [26:19] type
    // [18:14] len
    // [13:5]  ptr
    // [4:0]   reserved
    // ============================================================
    function automatic [31:0] pack_obj;
        input [4:0] epoch;
        input [7:0] typ;
        input [4:0] len;
        input [8:0] ptr;
        begin
            pack_obj = {epoch, typ, len, ptr, 5'b0};
        end
    endfunction

    wire [4:0] bram_epoch = w_bram_do[31:27];
    wire [7:0] bram_type  = w_bram_do[26:19];
    wire [4:0] bram_len   = w_bram_do[18:14];
    wire [8:0] bram_ptr   = w_bram_do[13:5];

    // ---------------- BRAM interface ----------------
    wire [31:0] w_bram_do;
    reg  [31:0] r_bram_di;
    reg  [8:0]  r_bram_wr_addr;
    reg  [8:0]  r_bram_rd_addr;
    reg         r_bram_wr_en;
    reg         r_bram_rd_en;

    // ============================================================
    // ALLOC FSM
    // ============================================================
    localparam A_IDLE   = 3'd0;
    localparam A_READ   = 3'd1;
    localparam A_WAIT   = 3'd2;
    localparam A_CHECK  = 3'd3;
    localparam A_WRITE  = 3'd4;
    localparam A_DONE   = 3'd5;

    reg [2:0] a_state;
    reg [8:0] a_scan;
    reg [4:0] a_epoch;
    reg [7:0] a_old_type;
    reg [4:0] a_old_len;
    reg [8:0] a_old_ptr;

    // ============================================================
    // READ pipeline for external read port
    // leitura síncrona contínua quando alloc não está usando a BRAM
    // ============================================================
    reg [8:0] rd_idx_q;
    reg       rd_valid_q;

    // ============================================================
    // Main control
    // ============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_state        <= A_IDLE;
            a_scan         <= 9'd0;
            a_epoch        <= 5'd0;
            a_old_type     <= 8'd0;
            a_old_len      <= 5'd0;
            a_old_ptr      <= 9'd0;

            o_alloc_ready  <= 1'b0;
            o_alloc_done   <= 1'b0;
            o_alloc_ok     <= 1'b0;
            o_alloc_idx    <= 9'd0;

            o_rd_type      <= 8'd0;
            o_rd_len       <= 5'd0;
            o_rd_ptr       <= 9'd0;
            o_rd_epoch     <= 5'd0;

            r_bram_di      <= 32'd0;
            r_bram_wr_addr <= 9'd0;
            r_bram_rd_addr <= 9'd0;
            r_bram_wr_en   <= 1'b0;
            r_bram_rd_en   <= 1'b0;

            rd_idx_q       <= 9'd0;
            rd_valid_q     <= 1'b0;
        end else begin
            // defaults
            r_bram_wr_en <= 1'b0;
            r_bram_rd_en <= 1'b0;
            o_alloc_done <= 1'b0;

            case (a_state)
                // ------------------------------------------------
                // Idle:
                // - allocation can start
                // - otherwise BRAM read is used by external read
                // ------------------------------------------------
                A_IDLE: begin
                    o_alloc_ok <= 1'b0;

                    if (i_alloc_start) begin
                        o_alloc_ready <= 1'b0;
                        a_scan        <= 9'd0;
                        a_epoch       <= i_alloc_epoch;
                        a_state       <= A_READ;
                        rd_valid_q    <= 1'b0;
                    end else begin
                        o_alloc_ready <= 1'b1;

                        // external read path
                        r_bram_rd_addr <= i_rd_idx;
                        r_bram_rd_en   <= 1'b1;
                        rd_idx_q       <= i_rd_idx;
                        rd_valid_q     <= 1'b1;

                        if (rd_valid_q) begin
                            o_rd_epoch <= bram_epoch;
                            o_rd_type  <= bram_type;
                            o_rd_len   <= bram_len;
                            o_rd_ptr   <= bram_ptr;
                        end
                    end
                end

                // ------------------------------------------------
                // Read current slot for allocation scan
                // ------------------------------------------------
                A_READ: begin
                    r_bram_rd_addr <= a_scan;
                    r_bram_rd_en   <= 1'b1;
                    a_state        <= A_WAIT;
                end

                // ------------------------------------------------
                // Wait BRAM latency
                // ------------------------------------------------
                A_WAIT: begin
                    a_state <= A_CHECK;
                end

                // ------------------------------------------------
                // Check if current slot is free/recyclable
                // rule kept from old design:
                // allocate when stored epoch > requested epoch
                // ------------------------------------------------
                A_CHECK: begin
                    if (bram_epoch > a_epoch) begin
                        a_old_type <= bram_type;
                        a_old_len  <= bram_len;
                        a_old_ptr  <= bram_ptr;
                        a_state    <= A_WRITE;
                    end else if (a_scan == NUM_VAR-1) begin
                        o_alloc_ok   <= 1'b0;
                        o_alloc_idx  <= 9'd0;
                        o_alloc_done <= 1'b1;
                        a_state      <= A_IDLE;
                    end else begin
                        a_scan  <= a_scan + 1'b1;
                        a_state <= A_READ;
                    end
                end

                // ------------------------------------------------
                // Write updated epoch back to same slot
                // preserve type/len/ptr content
                // ------------------------------------------------
                A_WRITE: begin
                    r_bram_wr_addr <= a_scan;
                    r_bram_di      <= pack_obj(a_epoch, a_old_type, a_old_len, a_old_ptr);
                    r_bram_wr_en   <= 1'b1;

                    o_alloc_idx    <= a_scan;
                    o_alloc_ok     <= 1'b1;
                    o_alloc_done   <= 1'b1;
                    a_state        <= A_IDLE;
                end

                default: begin
                    a_state <= A_IDLE;
                end
            endcase

            // ----------------------------------------------------
            // external write port
            // only when alloc FSM is idle
            // write preserves stored epoch
            // ----------------------------------------------------
            if ((a_state == A_IDLE) && i_wr_en) begin
                r_bram_wr_addr <= i_wr_idx;
                r_bram_di      <= pack_obj(o_rd_epoch, i_wr_type, i_wr_len, i_wr_ptr);
                r_bram_wr_en   <= 1'b1;
            end
        end
    end

    // ============================================================
    // BRAM
    // ============================================================
    BRAM_SDP_MACRO #(
        .BRAM_SIZE("18Kb"),
        .DEVICE("7SERIES"),
        .WRITE_WIDTH(32),
        .READ_WIDTH(32),
        .DO_REG(0),
        .INIT_FILE("NONE"),
        .SIM_COLLISION_CHECK("ALL"),
        .SRVAL(72'h000000000000000000),
        .INIT(72'h000000000000000000),
        .WRITE_MODE("WRITE_FIRST"),

        .INIT_00(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_01(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_02(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_03(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_04(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_05(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_06(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_07(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_08(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_09(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_0A(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_0B(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_0C(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_0D(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_0E(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_0F(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_10(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_11(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_12(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_13(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_14(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_15(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_16(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_17(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_18(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_19(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_1A(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_1B(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_1C(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_1D(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_1E(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_1F(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_20(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_21(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_22(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_23(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_24(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_25(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_26(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_27(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_28(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_29(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_2A(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_2B(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_2C(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_2D(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_2E(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_2F(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_30(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_31(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_32(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_33(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_34(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_35(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_36(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_37(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_38(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_39(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_3A(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_3B(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_3C(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_3D(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_3E(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        .INIT_3F(256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),

        .INITP_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_05(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_06(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INITP_07(256'h0000000000000000000000000000000000000000000000000000000000000000)
    ) BRAM_SDP_MACRO_inst (
        .DO(w_bram_do),
        .DI(r_bram_di),
        .RDADDR(r_bram_rd_addr),
        .RDCLK(clk),
        .RDEN(r_bram_rd_en),
        .REGCE(1'b1),
        .RST(rst),
        .WE(4'b1111),
        .WRADDR(r_bram_wr_addr),
        .WRCLK(clk),
        .WREN(r_bram_wr_en)
    );

endmodule