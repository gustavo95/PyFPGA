`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.03.2026 19:55:00
// Design Name: 
// Module Name: mem_object
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


module mem_object #(
    parameter NUM_VAR = 512
)(
    input  wire        clk,
    input  wire        rst,

    // ---------- ALLOC ----------
    input  wire        i_alloc_start,    // start allocation request
    input  wire [4:0]  i_alloc_epoch,    // epoch of variable to be allocated
    output reg         o_alloc_ready,    // ready to receive allocation request
    output reg         o_alloc_done,     // allocation done
    output reg         o_alloc_ok,       // allocation successful
    output reg  [8:0]  o_alloc_idx,      // return index of allocated variable

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
    output reg  [8:0]  o_rd_ptr
);

    // ----------------- MEMORY ----------------
    reg [26:0] mem  [0:NUM_VAR-1]; // 512 x 26-bit memory
    reg [4:0] epoch [0:NUM_VAR-1];

    // ---------------- ALLOC FSM ----------------
    localparam A_IDLE = 2'd0, A_SCAN = 2'd1;
    reg [1:0] a_state;
    reg [8:0] a_scan;
    reg [4:0] a_epoch;
    integer i;

    // ----------------- ALLOC IMPLEMENTATION ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_state <= A_IDLE;
            o_alloc_ready <= 0;
            o_alloc_done <= 0;
            o_alloc_ok <= 0;
            o_alloc_idx <= 0;
            for (i = 0; i < NUM_VAR; i = i + 1) begin
                epoch[i] <= 5'd31;
            end
        end else begin
            case (a_state)
                A_IDLE: begin
                    o_alloc_ok <= 0;
                    o_alloc_done <= 0;
                    if (i_alloc_start) begin
                        a_scan <= 0;
                        a_epoch <= i_alloc_epoch;
                        o_alloc_ready <= 0;
                        a_state <= A_SCAN;
                    end else begin
                        o_alloc_ready <= 1;
                    end
                end
                A_SCAN: begin
                    if (epoch[a_scan] > a_epoch) begin
                        epoch[a_scan] <= a_epoch; // allocate this slot
                        o_alloc_idx <= a_scan; // found a free slot, return index
                        o_alloc_ok <= 1;
                        o_alloc_done <= 1;
                        a_state <= A_IDLE; // done with success
                    end else if (a_scan == NUM_VAR - 1) begin
                        o_alloc_done <= 1;
                        a_state <= A_IDLE; // no match found, done with failure
                    end else begin
                        a_scan <= a_scan + 1; // continue scanning
                    end
                end
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_rd_type <= 0;
            o_rd_len  <= 0;
            o_rd_ptr  <= 0;
        end else begin
            if (i_wr_en) begin
                mem[i_wr_idx] <= {i_wr_type, i_wr_len, i_wr_ptr};
            end
            
            {o_rd_type, o_rd_len, o_rd_ptr} <= mem[i_rd_idx];
        end
    end
endmodule