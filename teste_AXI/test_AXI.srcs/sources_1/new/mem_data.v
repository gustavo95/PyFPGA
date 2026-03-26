`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.03.2026 19:54:14
// Design Name: 
// Module Name: mem_data
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


module mem_data #(
    parameter PAGE_WORDS = 16,
    parameter NUM_PAGES  = 32
)(
    input  wire clk,
    input  wire rst,

    // ---------- ALLOC ----------
    input  wire       i_alloc_start,    // satrt mem allocation
    input  wire [4:0] i_alloc_len,      // data length to allocate in words (32 bits)
    input  wire [4:0] i_alloc_epoch,    // epoch to allocated data
    output reg        o_alloc_ready,    // ready to receive allocation request
    output reg        o_alloc_done,     // allocation done
    output reg        o_alloc_ok,       // allocation successful
    output reg [8:0]  o_alloc_ptr,      // return pointer

    // ---------- WRITE PAYLOAD ----------
    input  wire       i_wr_start,       // start write payload
    input  wire [8:0] i_wr_ptr,         // write pointer (page_idx + word_idx)
    input  wire [4:0] i_wr_len,         // length in words (32 bits) to write
    input  wire [31:0] i_wr_data,       // data to write
    input  wire       i_wr_tick,        // write tick (data valid)
    output reg        o_wr_ready,       // ready to receive data
    output reg        o_wr_done,        // write done
    output reg        o_wr_ok,          // write successful

    // ---------- READ PAYLOAD / STREAM ----------
    input  wire       i_rd_start,       // start read payload
    input  wire [8:0] i_rd_ptr,         // read pointer (page_idx + word_idx)
    input  wire [4:0] i_rd_len,         // length in words (32 bits) to read
    output reg [31:0] o_rd_data,        // data read
    output reg        o_rd_ready,       // ready to receive data
    output reg  [4:0] o_rd_idx,         // read index (0 to PAGE_WORDS-1)
    output reg        o_rd_done,        // read done
    output reg        o_rd_ok,          // read successful (pointer valid)
    output reg        o_rd_tick         // read tick (data valid)
);

   // ---------------- Page bitmap ----------------
   reg [4:0] page_free [0:NUM_PAGES-1];
   reg [4:0] page_epoch[0:NUM_PAGES-1];
    
   // ---------------- BRAM interface wires ----------------
   wire [31:0] w_bram_do;
   reg  [31:0] r_bram_di;
   reg  [8:0]  r_bram_wr_addr, r_bram_rd_addr;
   reg  r_bram_wr_en, r_bram_rd_en;
   
   // ---------------- Helpers ----------------
    function automatic [8:0] mk_addr;
        input [4:0] p;
        input [3:0] w;
        begin
            mk_addr = {p, w}; // p*16 + w
        end
    endfunction

    // ---------------- ALLOC FSM ----------------
    localparam A_IDLE = 2'd0, A_SCAN = 2'd1, A_DONE = 2'd2;
    reg [1:0] a_state;
    reg [4:0] a_scan;
    reg [4:0] a_len;
    reg [4:0] a_epoch;
    integer i;

    // ---------------- WRITE FSM ----------------
    localparam W_IDLE = 2'd0, W_WAIT_TICK = 2'd1, W_RUN = 2'd2, W_WAIT_OK = 2'd3;
    reg [1:0] w_state;
    reg [4:0] w_page;
    reg [3:0] w_idx;
    reg [3:0] w_total;

    // ---------------- READ FSM ----------------
    localparam R_IDLE = 3'd0, R_READ = 3'd1, R_WAIT = 3'd2,R_OUT = 3'd3;
    reg [2:0] r_state;
    reg [4:0] r_page;
    reg [3:0] r_idx;
    reg [3:0] r_total;
    reg [4:0] r_page_q;   // captura página lida (pra estabilidade, se quiser)
    reg [3:0] r_idx_q;

    // ---------------- ALLOC implementation ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < NUM_PAGES; i = i + 1) begin
                page_free[i]  <= PAGE_WORDS;
                page_epoch[i] <= 5'd31;
            end
            o_alloc_ready <= 1'b0;
            o_alloc_done  <= 1'b0;
            o_alloc_ok    <= 1'b0;
            o_alloc_ptr   <= 9'b0;
            a_state       <= A_IDLE;
        end else begin
            case (a_state)
                A_IDLE: begin
                    if (i_alloc_start) begin
                        o_alloc_ready <= 1'b0;
                        if (i_alloc_len == 0 || i_alloc_len > PAGE_WORDS) begin
                            o_alloc_ok   <= 0;
                            o_alloc_ptr  <= 0;
                            o_alloc_done <= 1;
                        end else begin
                            a_len   <= i_alloc_len;
                            a_epoch <= i_alloc_epoch;
                            a_scan  <= 0;
                            a_state <= A_SCAN;
                        end
                    end
                    else begin
                        o_alloc_ready <= 1'b1;
                        o_alloc_ok   <= 0;
                        o_alloc_ptr  <= 0;
                        o_alloc_done <= 0;
                    end
                end

                A_SCAN: begin
                    if (page_epoch[a_scan] == a_epoch && page_free[a_scan] >= a_len) begin
                        page_free[a_scan]  <= page_free[a_scan] - a_len;

                        o_alloc_ptr        <= mk_addr(a_scan, PAGE_WORDS - page_free[a_scan]);
                        o_alloc_ok         <= 1'b1;
                        o_alloc_done       <= 1'b1;
                        a_state            <= A_IDLE;
                    end else if (page_epoch[a_scan] > a_epoch) begin
                        page_epoch[a_scan] <= a_epoch;
                        page_free[a_scan]  <= PAGE_WORDS - a_len;

                        o_alloc_ptr        <= mk_addr(a_scan, 5'b0);
                        o_alloc_ok         <= 1'b1;
                        o_alloc_done       <= 1'b1;
                        a_state            <= A_IDLE;
                    end else begin
                        if (a_scan == (NUM_PAGES-1)) begin
                            o_alloc_ok   <= 0;
                            o_alloc_ptr  <= 0;
                            o_alloc_done <= 1'b1;
                            a_state      <= A_IDLE;
                        end else begin
                            a_scan <= a_scan + 1;
                        end
                    end
                end
            endcase
        end
    end

    // ---------------- WRITE implementation ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_wr_ready <= 1'b0;
            o_wr_done  <= 1'b0;
            o_wr_ok    <= 1'b0;
            r_bram_wr_en <= 1'b0;
            w_state     <= W_IDLE;
        end else begin
            case (w_state)
                W_IDLE: begin
                    r_bram_wr_en <= 1'b0;
                    o_wr_ok    <= 1'b0;
                    if (i_wr_start) begin
                        o_wr_ready <= 1'b0;
                        if (i_wr_len == 0 || i_wr_len > PAGE_WORDS) begin
                            o_wr_done  <= 1'b1;
                            w_state    <= W_IDLE;
                        end else begin
                            w_page  <= i_wr_ptr[8:4];
                            w_idx   <= i_wr_ptr[3:0];
                            w_total <= i_wr_len;
                            o_wr_done  <= 1'b0;
                            w_state    <= W_WAIT_TICK;
                        end
                    end else begin
                        o_wr_ready <= 1'b1;
                        o_wr_done  <= 1'b0;
                    end
                end

                W_WAIT_TICK: begin
                    o_wr_ok <= 1'b0;
                    r_bram_wr_en <= 1'b0;
                    if (i_wr_tick) begin
                        w_total <= w_total - 1;
                        w_state <= W_RUN;
                    end
                end

                W_RUN: begin
                    r_bram_wr_addr <= mk_addr(w_page, w_idx);
                    r_bram_di <= i_wr_data;
                    r_bram_wr_en <= 1'b1;
                    if (w_total == 0) begin
                        o_wr_done <= 1'b1;
                        o_wr_ok   <= 1'b1;
                        w_state   <= W_IDLE;
                    end else begin
                        w_idx <= w_idx + 1;
                        o_wr_ok <= 1'b1;
                        w_state <= W_WAIT_OK;
                    end
                end

                W_WAIT_OK: begin
                    o_wr_ok <= 1'b0;
                    if (!i_wr_tick) begin
                        w_state <= W_WAIT_TICK;
                    end
                end
            endcase
        end
    end

    // ---------------- READ implementation ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_rd_data   <= 32'b0;
            o_rd_ready  <= 1'b0;
            o_rd_idx    <= 4'b0;
            o_rd_done   <= 1'b0;
            o_rd_ok     <= 1'b0;
            o_rd_tick   <= 1'b0;
            r_bram_rd_en <= 1'b0;
            r_state     <= R_IDLE;
        end else begin
            case (r_state)
                R_IDLE: begin
                    r_bram_rd_en <= 1'b0;
                    if (i_rd_start) begin
                        o_rd_ready <= 1'b0;
                        if (i_rd_len == 0 || i_rd_len > PAGE_WORDS) begin
                            o_rd_done  <= 1'b1;
                            o_rd_tick  <= 1'b1;
                            r_state    <= R_IDLE;
                        end else begin
                            r_page  <= i_rd_ptr[8:4];
                            r_idx   <= i_rd_ptr[3:0];
                            r_total <= i_rd_len;
                            o_rd_done  <= 1'b0;
                            o_rd_idx   <= 4'b0;
                            o_rd_tick  <= 1'b0;
                            r_state <= R_READ;
                        end
                    end else begin
                        o_rd_ready <= 1'b1;
                        o_rd_done  <= 1'b0;
                        o_rd_ok    <= 1'b0;
                        o_rd_idx   <= 4'b0;
                        o_rd_tick  <= 1'b0;
                    end
                end

                R_READ: begin
                    r_bram_rd_addr <= mk_addr(r_page, r_idx);
                    r_bram_rd_en <= 1'b1;
                    r_total <= r_total - 1;
                    o_rd_tick <= 1'b0;
                    r_state <= R_WAIT;
                end

                R_WAIT: begin
                    r_state <= R_OUT;
                end
                
                R_OUT: begin
                    o_rd_data <= w_bram_do;
                    r_bram_rd_en <= 1'b0;
                    o_rd_idx  <= o_rd_idx + 1;
                    o_rd_tick <= 1'b1;
                    o_rd_ok   <= 1'b1;
                    if (r_total == 0) begin
                        o_rd_done <= 1'b1;
                        r_state   <= R_IDLE;
                    end else begin
                        r_idx <= r_idx + 1;
                        r_state <= R_READ;
                    end
                end
            endcase
        end
    end
    
   // BRAM_SDP_MACRO: Simple Dual Port RAM
   //                 Artix-7
   // Xilinx HDL Language Template, version 2024.1

   ///////////////////////////////////////////////////////////////////////
   //  READ_WIDTH | BRAM_SIZE | READ Depth  | RDADDR Width |            //
   // WRITE_WIDTH |           | WRITE Depth | WRADDR Width |  WE Width  //
   // ============|===========|=============|==============|============//
   //    37-72    |  "36Kb"   |      512    |     9-bit    |    8-bit   //
   //    19-36    |  "36Kb"   |     1024    |    10-bit    |    4-bit   //
   //    19-36    |  "18Kb"   |      512    |     9-bit    |    4-bit   //
   //    10-18    |  "36Kb"   |     2048    |    11-bit    |    2-bit   //
   //    10-18    |  "18Kb"   |     1024    |    10-bit    |    2-bit   //
   //     5-9     |  "36Kb"   |     4096    |    12-bit    |    1-bit   //
   //     5-9     |  "18Kb"   |     2048    |    11-bit    |    1-bit   //
   //     3-4     |  "36Kb"   |     8192    |    13-bit    |    1-bit   //
   //     3-4     |  "18Kb"   |     4096    |    12-bit    |    1-bit   //
   //       2     |  "36Kb"   |    16384    |    14-bit    |    1-bit   //
   //       2     |  "18Kb"   |     8192    |    13-bit    |    1-bit   //
   //       1     |  "36Kb"   |    32768    |    15-bit    |    1-bit   //
   //       1     |  "18Kb"   |    16384    |    14-bit    |    1-bit   //
   ///////////////////////////////////////////////////////////////////////

   BRAM_SDP_MACRO #(
      .BRAM_SIZE("18Kb"), // Target BRAM, "18Kb" or "36Kb" 
      .DEVICE("7SERIES"), // Target device: "7SERIES" 
      .WRITE_WIDTH(32),    // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      .READ_WIDTH(32),     // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      .DO_REG(0),         // Optional output register (0 or 1)
      .INIT_FILE ("NONE"),
      .SIM_COLLISION_CHECK ("ALL"), // Collision check enable "ALL", "WARNING_ONLY",
                                    //   "GENERATE_X_ONLY" or "NONE" 
      .SRVAL(72'h000000000000000000), // Set/Reset value for port output
      .INIT(72'h000000000000000000),  // Initial values on output port
      .WRITE_MODE("WRITE_FIRST"),  // Specify "READ_FIRST" for same clock or synchronous clocks
                                   //   Specify "WRITE_FIRST for asynchronous clocks on ports
      .INIT_00(256'h1111111100000000000000000000000000000000000000000000001110101010),
      .INIT_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_05(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_06(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_07(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_08(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_09(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0A(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0B(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0C(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0D(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0E(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_0F(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_10(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_11(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_12(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_13(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_14(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_15(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_16(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_17(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_18(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_19(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_1A(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_1B(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_1C(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_1D(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_1E(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_1F(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_20(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_21(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_22(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_23(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_24(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_25(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_26(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_27(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_28(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_29(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_2A(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_2B(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_2C(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_2D(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_2E(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_2F(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_30(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_31(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_32(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_33(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_34(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_35(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_36(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_37(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_38(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_39(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_3A(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_3B(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_3C(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_3D(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_3E(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INIT_3F(256'h0000000000000000000000000000000000000000000000000000000000000000),


      // The next set of INITP_xx are for the parity bits
      .INITP_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_05(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_06(256'h0000000000000000000000000000000000000000000000000000000000000000),
      .INITP_07(256'h0000000000000000000000000000000000000000000000000000000000000000)

   ) BRAM_SDP_MACRO_inst (
      .DO(w_bram_do),         // Output read data port, width defined by READ_WIDTH parameter
      .DI(r_bram_di),         // Input write data port, width defined by WRITE_WIDTH parameter
      .RDADDR(r_bram_rd_addr), // Input read address, width defined by read port depth
      .RDCLK(clk),   // 1-bit input read clock
      .RDEN(r_bram_rd_en),     // 1-bit input read port enable
      .REGCE(1'b1),   // 1-bit input read output register enable
      .RST(rst),       // 1-bit input reset
      .WE(4'b1111),         // Input write enable, width defined by write port depth
      .WRADDR(r_bram_wr_addr), // Input write address, width defined by write port depth
      .WRCLK(clk),   // 1-bit input write clock
      .WREN(r_bram_wr_en)      // 1-bit input write port enable
   );
    
endmodule