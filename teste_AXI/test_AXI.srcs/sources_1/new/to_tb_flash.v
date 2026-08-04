`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:
// Design Name:
// Module Name: top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//   Top de teste para o flash_driver / axi_quad_spi_0.
//
// Buttons:
//   BTN D = reset
//   BTN C = sem uso
//   BTN U = escreve SW[7:0] em IPIER
//   BTN R = le IPIER
//   BTN L = le SPISR
//
// Switches:
//   SW[7:0] = valor de escrita para IPIER
//
// Display:
//   mostra os 16 bits menos significativos da ultima leitura
//////////////////////////////////////////////////////////////////////////////////

module top(
    input clk,

    // Buttons
    input i_btn_l,
    input i_btn_r,
    input i_btn_u,
    input i_btn_d,
    input i_btn_c,

    // Switches
    input [15:0] i_sw,

    // LEDs
    output reg [15:0] o_led,

    // Display 7 segmentos
    output [7:0] o_hex,
    output [3:0] o_hex_select,

    // QSPI pins
    inout        qspi_dq0,
    inout        qspi_dq1,
    inout        qspi_dq2,
    inout        qspi_dq3,
    inout        qspi_cs_n
);

    localparam [6:0] REG_IPIER   = 7'h28;
    localparam [6:0] REG_SPISR   = 7'h64;

    localparam [3:0] ST_IDLE          = 4'd0;
    localparam [3:0] ST_WAIT_OP       = 4'd1;

    // =========================================================
    // Debounce buttons
    // =========================================================
    wire w_btn_l;
    wire w_btn_r;
    wire w_btn_u;
    wire w_btn_d;
    wire w_btn_c;

    debounce db_btn_l (.clk(clk), .i_btn(i_btn_l), .o_btn(w_btn_l));
    debounce db_btn_r (.clk(clk), .i_btn(i_btn_r), .o_btn(w_btn_r));
    debounce db_btn_u (.clk(clk), .i_btn(i_btn_u), .o_btn(w_btn_u));
    debounce db_btn_d (.clk(clk), .i_btn(i_btn_d), .o_btn(w_btn_d));
    debounce db_btn_c (.clk(clk), .i_btn(i_btn_c), .o_btn(w_btn_c));

    // =========================================================
    // Clock divider
    // =========================================================
    wire [15:0] clk_div;

    clk_div clk_div_inst (
        .clk(clk),
        .rst(w_btn_d),
        .clk_div(clk_div)
    );

    // =========================================================
    // Edge detect
    // =========================================================
    reg r_btn_l_prev;
    reg r_btn_r_prev;
    reg r_btn_u_prev;

    wire w_btn_l_pulse = w_btn_l & ~r_btn_l_prev;
    wire w_btn_r_pulse = w_btn_r & ~r_btn_r_prev;
    wire w_btn_u_pulse = w_btn_u & ~r_btn_u_prev;

    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            r_btn_l_prev <= 1'b0;
            r_btn_r_prev <= 1'b0;
            r_btn_u_prev <= 1'b0;
        end else begin
            r_btn_l_prev <= w_btn_l;
            r_btn_r_prev <= w_btn_r;
            r_btn_u_prev <= w_btn_u;
        end
    end

    // =========================================================
    // Display
    // =========================================================
    reg [7:0] r_byte1_print;
    reg [7:0] r_byte2_print;

    // =========================================================
    // flash_driver interface
    // =========================================================
    reg        r_flash_start;
    reg        r_flash_write;
    reg [6:0]  r_flash_addr;
    reg [31:0] r_flash_wdata;
    reg [3:0]  r_flash_wstrb;
    wire       w_flash_ready;
    wire       w_flash_busy;
    wire       w_flash_done;
    wire [31:0] w_flash_rdata;
    wire [1:0]  w_flash_resp;
    wire        w_flash_error;

    // =========================================================
    // Test control
    // =========================================================
    reg [3:0]  r_state;
    reg [6:0]  r_last_addr;
    reg        r_last_write;
    reg [31:0] r_last_rdata;
    reg [1:0]  r_last_resp;
    reg        r_last_error;
    reg        r_last_done;

    wire [0:0] w_ss_i = 1'b1;
    wire w_cfgclk;
    wire w_cfgmclk;
    wire w_eos;
    wire w_preq;
    wire w_qspi_irq;
    wire w_io0_i;
    wire w_io0_o;
    wire w_io0_t;
    wire w_io1_i;
    wire w_io1_o;
    wire w_io1_t;
    wire w_io2_i;
    wire w_io2_o;
    wire w_io2_t;
    wire w_io3_i;
    wire w_io3_o;
    wire w_io3_t;
    wire [0:0] w_ss_o;
    wire w_ss_t;

    task automatic start_write;
        input [6:0] addr;
        input [31:0] data;
        begin
            r_flash_addr  <= addr;
            r_flash_wdata <= data;
            r_flash_wstrb <= 4'hF;
            r_flash_write <= 1'b1;
            r_flash_start <= 1'b1;

            r_last_addr   <= addr;
            r_last_write  <= 1'b1;
            r_last_done   <= 1'b0;
        end
    endtask

    task automatic start_read;
        input [6:0] addr;
        begin
            r_flash_addr  <= addr;
            r_flash_wdata <= 32'd0;
            r_flash_wstrb <= 4'h0;
            r_flash_write <= 1'b0;
            r_flash_start <= 1'b1;

            r_last_addr   <= addr;
            r_last_write  <= 1'b0;
            r_last_done   <= 1'b0;
        end
    endtask

    // =========================================================
    // Main FSM
    // =========================================================
    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            r_state       <= ST_IDLE;
            r_flash_start <= 1'b0;
            r_flash_write <= 1'b0;
            r_flash_addr  <= 7'd0;
            r_flash_wdata <= 32'd0;
            r_flash_wstrb <= 4'd0;

            r_last_addr   <= 7'd0;
            r_last_write  <= 1'b0;
            r_last_rdata  <= 32'd0;
            r_last_resp   <= 2'b00;
            r_last_error  <= 1'b0;
            r_last_done   <= 1'b0;
        end else begin
            r_flash_start <= 1'b0;

            if (w_flash_done) begin
                r_last_done  <= 1'b1;
                r_last_rdata <= w_flash_rdata;
                r_last_resp  <= w_flash_resp;
                r_last_error <= w_flash_error;
            end

            case (r_state)
                ST_IDLE: begin
                    if (w_btn_u_pulse && w_flash_ready) begin
                        start_write(REG_IPIER, {24'd0, i_sw[7:0]});
                        r_state <= ST_WAIT_OP;
                    end else if (w_btn_r_pulse && w_flash_ready) begin
                        start_read(REG_IPIER);
                        r_state <= ST_WAIT_OP;
                    end else if (w_btn_l_pulse && w_flash_ready) begin
                        start_read(REG_SPISR);
                        r_state <= ST_WAIT_OP;
                    end
                end

                ST_WAIT_OP: begin
                    if (w_flash_done) begin
                        r_state <= ST_IDLE;
                    end
                end

                default: begin
                    r_state <= ST_IDLE;
                end
            endcase
        end
    end

    // =========================================================
    // LEDs
    // =========================================================
    always @(posedge clk or posedge w_btn_d) begin
        if (w_btn_d) begin
            o_led <= 16'd0;
        end else begin
            o_led[6:0]   <= r_last_addr;
            o_led[7]     <= r_last_write;
            o_led[8]     <= r_last_done;
            o_led[9]     <= r_last_error;
            o_led[10]    <= w_flash_ready;
            o_led[11]    <= w_flash_busy;
            o_led[13:12] <= r_last_resp;
            o_led[14]    <= w_flash_ready;
            o_led[15]    <= w_qspi_irq;
        end
    end

    // =========================================================
    // Display
    // =========================================================
    always @(*) begin
        r_byte1_print = r_last_rdata[7:0];
        r_byte2_print = r_last_rdata[15:8];
    end

    display7 d7(
        .clk_1KHz(clk_div[15]),
        .rst(w_btn_d),
        .i_byte1(r_byte1_print),
        .i_byte2(r_byte2_print),
        .o_hex(o_hex),
        .o_hex_select(o_hex_select)
    );

    // =========================================================
    // QSPI IOBUFs
    // =========================================================
    IOBUF iobuf_qspi_dq0 (
        .I (w_io0_o),
        .O (w_io0_i),
        .IO(qspi_dq0),
        .T (w_io0_t)
    );

    IOBUF iobuf_qspi_dq1 (
        .I (w_io1_o),
        .O (w_io1_i),
        .IO(qspi_dq1),
        .T (w_io1_t)
    );

    IOBUF iobuf_qspi_dq2 (
        .I (w_io2_o),
        .O (w_io2_i),
        .IO(qspi_dq2),
        .T (w_io2_t)
    );

    IOBUF iobuf_qspi_dq3 (
        .I (w_io3_o),
        .O (w_io3_i),
        .IO(qspi_dq3),
        .T (w_io3_t)
    );

    IOBUF iobuf_qspi_cs_n (
        .I (w_ss_o[0]),
        .O (),
        .IO(qspi_cs_n),
        .T (w_ss_t)
    );

    // =========================================================
    // DUT
    // =========================================================
    flash_driver flash_driver_inst (
        .clk        (clk),
        .rst        (w_btn_d),
        .i_spi_clk  (clk_div[2]),

        .i_start    (r_flash_start),
        .i_write    (r_flash_write),
        .i_addr     (r_flash_addr),
        .i_wdata    (r_flash_wdata),
        .i_wstrb    (r_flash_wstrb),
        .o_ready    (w_flash_ready),
        .o_busy     (w_flash_busy),
        .o_done     (w_flash_done),
        .o_rdata    (w_flash_rdata),
        .o_resp     (w_flash_resp),
        .o_error    (w_flash_error),

        .qspi_io0_i (w_io0_i),
        .qspi_io0_o (w_io0_o),
        .qspi_io0_t (w_io0_t),
        .qspi_io1_i (w_io1_i),
        .qspi_io1_o (w_io1_o),
        .qspi_io1_t (w_io1_t),
        .qspi_io2_i (w_io2_i),
        .qspi_io2_o (w_io2_o),
        .qspi_io2_t (w_io2_t),
        .qspi_io3_i (w_io3_i),
        .qspi_io3_o (w_io3_o),
        .qspi_io3_t (w_io3_t),
        .qspi_ss_i  (w_ss_i),
        .qspi_ss_o  (w_ss_o),
        .qspi_ss_t  (w_ss_t),
        .qspi_cfgclk(w_cfgclk),
        .qspi_cfgmclk(w_cfgmclk),
        .qspi_eos   (w_eos),
        .qspi_preq  (w_preq),
        .qspi_irq   (w_qspi_irq)
    );

endmodule
