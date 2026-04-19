`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 19.04.2026
// Design Name:
// Module Name: flash_driver
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//   Wrapper para o IP axi_quad_spi_0.
//   Apos reset, o modulo inicializa o QSPI automaticamente e so entao
//   libera o_ready para acessos externos.
//////////////////////////////////////////////////////////////////////////////////

module flash_driver (
    input  wire        clk,
    input  wire        rst,
    input  wire        i_spi_clk,

    // ---------------------------------------------------------
    // System side
    // ---------------------------------------------------------
    input  wire        i_start,
    input  wire        i_write,
    input  wire [6:0]  i_addr,
    input  wire [31:0] i_wdata,
    input  wire [3:0]  i_wstrb,
    output reg         o_ready,
    output reg         o_busy,
    output reg         o_done,
    output reg [31:0]  o_rdata,
    output reg [1:0]   o_resp,
    output reg         o_error,

    // ---------------------------------------------------------
    // QSPI side
    // ---------------------------------------------------------
    input  wire        qspi_io0_i,
    output wire        qspi_io0_o,
    output wire        qspi_io0_t,
    input  wire        qspi_io1_i,
    output wire        qspi_io1_o,
    output wire        qspi_io1_t,
    input  wire        qspi_io2_i,
    output wire        qspi_io2_o,
    output wire        qspi_io2_t,
    input  wire        qspi_io3_i,
    output wire        qspi_io3_o,
    output wire        qspi_io3_t,
    input  wire [0:0]  qspi_ss_i,
    output wire [0:0]  qspi_ss_o,
    output wire        qspi_ss_t,
    output wire        qspi_cfgclk,
    output wire        qspi_cfgmclk,
    output wire        qspi_eos,
    output wire        qspi_preq,
    output wire        qspi_irq
);

    localparam [6:0] REG_SRR     = 7'h40;
    localparam [6:0] REG_SPICR   = 7'h60;
    localparam [6:0] REG_SPI_SSR = 7'h70;

    localparam [31:0] SRR_RESET_VALUE   = 32'h0000000A;
    localparam [31:0] SPI_SSR_ASSERT_SS = 32'h00000000;
    localparam [31:0] SPI_CR_INIT_VALUE = 32'h000000E6;

    localparam [3:0] ST_BOOT_RESET = 4'd0;
    localparam [3:0] ST_BOOT_SSR   = 4'd1;
    localparam [3:0] ST_BOOT_SPICR = 4'd2;
    localparam [3:0] ST_IDLE       = 4'd3;
    localparam [3:0] ST_WRITE_REQ  = 4'd4;
    localparam [3:0] ST_WRITE_RESP = 4'd5;
    localparam [3:0] ST_READ_ADDR  = 4'd6;
    localparam [3:0] ST_READ_DATA  = 4'd7;

    reg [3:0]  r_state;
    reg [1:0]  r_boot_step;
    reg        r_aw_done;
    reg        r_w_done;
    reg        r_init_error;
    reg        r_is_boot_write;

    reg [6:0]  r_axi_awaddr;
    reg        r_axi_awvalid;
    wire       w_axi_awready;

    reg [31:0] r_axi_wdata;
    reg [3:0]  r_axi_wstrb;
    reg        r_axi_wvalid;
    wire       w_axi_wready;

    wire [1:0] w_axi_bresp;
    wire       w_axi_bvalid;
    reg        r_axi_bready;

    reg [6:0]  r_axi_araddr;
    reg        r_axi_arvalid;
    wire       w_axi_arready;

    wire [31:0] w_axi_rdata;
    wire [1:0]  w_axi_rresp;
    wire        w_axi_rvalid;
    reg         r_axi_rready;

    wire w_axi_resetn = ~rst;

    task automatic launch_write;
        input [6:0] addr;
        input [31:0] data;
        input [3:0] strb;
        input is_boot;
        begin
            r_axi_awaddr   <= addr;
            r_axi_wdata    <= data;
            r_axi_wstrb    <= strb;
            r_axi_awvalid  <= 1'b1;
            r_axi_wvalid   <= 1'b1;
            r_axi_bready   <= 1'b0;
            r_aw_done      <= 1'b0;
            r_w_done       <= 1'b0;
            r_is_boot_write<= is_boot;
            r_state        <= ST_WRITE_REQ;
        end
    endtask

    task automatic launch_read;
        input [6:0] addr;
        begin
            r_axi_araddr   <= addr;
            r_axi_arvalid  <= 1'b1;
            r_axi_rready   <= 1'b0;
            r_state        <= ST_READ_ADDR;
        end
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_state        <= ST_BOOT_RESET;
            r_boot_step    <= 2'd0;
            r_aw_done      <= 1'b0;
            r_w_done       <= 1'b0;
            r_init_error   <= 1'b0;
            r_is_boot_write<= 1'b0;

            r_axi_awaddr   <= 7'd0;
            r_axi_awvalid  <= 1'b0;
            r_axi_wdata    <= 32'd0;
            r_axi_wstrb    <= 4'd0;
            r_axi_wvalid   <= 1'b0;
            r_axi_bready   <= 1'b0;
            r_axi_araddr   <= 7'd0;
            r_axi_arvalid  <= 1'b0;
            r_axi_rready   <= 1'b0;

            o_ready        <= 1'b0;
            o_busy         <= 1'b1;
            o_done         <= 1'b0;
            o_rdata        <= 32'd0;
            o_resp         <= 2'b00;
            o_error        <= 1'b0;
        end else begin
            o_done <= 1'b0;

            case (r_state)
                ST_BOOT_RESET: begin
                    o_ready     <= 1'b0;
                    o_busy      <= 1'b1;
                    o_error     <= r_init_error;
                    r_boot_step <= 2'd0;
                    launch_write(REG_SRR, SRR_RESET_VALUE, 4'hF, 1'b1);
                end

                ST_BOOT_SSR: begin
                    o_ready     <= 1'b0;
                    o_busy      <= 1'b1;
                    o_error     <= r_init_error;
                    r_boot_step <= 2'd1;
                    launch_write(REG_SPI_SSR, SPI_SSR_ASSERT_SS, 4'hF, 1'b1);
                end

                ST_BOOT_SPICR: begin
                    o_ready     <= 1'b0;
                    o_busy      <= 1'b1;
                    o_error     <= r_init_error;
                    r_boot_step <= 2'd2;
                    launch_write(REG_SPICR, SPI_CR_INIT_VALUE, 4'hF, 1'b1);
                end

                ST_IDLE: begin
                    o_ready       <= 1'b1;
                    o_busy        <= 1'b0;
                    o_resp        <= 2'b00;
                    o_error       <= r_init_error;
                    r_axi_awvalid <= 1'b0;
                    r_axi_wvalid  <= 1'b0;
                    r_axi_bready  <= 1'b0;
                    r_axi_arvalid <= 1'b0;
                    r_axi_rready  <= 1'b0;

                    if (i_start) begin
                        o_ready <= 1'b0;
                        o_busy  <= 1'b1;

                        if (i_write) begin
                            launch_write(i_addr, i_wdata, i_wstrb, 1'b0);
                        end else begin
                            launch_read(i_addr);
                        end
                    end
                end

                ST_WRITE_REQ: begin
                    o_busy <= 1'b1;

                    if (r_axi_awvalid && w_axi_awready) begin
                        r_axi_awvalid <= 1'b0;
                        r_aw_done     <= 1'b1;
                    end

                    if (r_axi_wvalid && w_axi_wready) begin
                        r_axi_wvalid <= 1'b0;
                        r_w_done     <= 1'b1;
                    end

                    if ((r_aw_done || (r_axi_awvalid && w_axi_awready)) &&
                        (r_w_done  || (r_axi_wvalid  && w_axi_wready))) begin
                        r_axi_bready <= 1'b1;
                        r_state      <= ST_WRITE_RESP;
                    end
                end

                ST_WRITE_RESP: begin
                    o_busy <= 1'b1;

                    if (r_axi_bready && w_axi_bvalid) begin
                        r_axi_bready <= 1'b0;
                        o_resp       <= w_axi_bresp;
                        o_error      <= (w_axi_bresp != 2'b00);

                        if (w_axi_bresp != 2'b00) begin
                            r_init_error <= 1'b1;
                        end

                        if (r_is_boot_write) begin
                            case (r_boot_step)
                                2'd0: r_state <= ST_BOOT_SSR;
                                2'd1: r_state <= ST_BOOT_SPICR;
                                default: begin
                                    o_busy  <= 1'b0;
                                    r_state <= ST_IDLE;
                                end
                            endcase
                        end else begin
                            o_done  <= 1'b1;
                            o_busy  <= 1'b0;
                            r_state <= ST_IDLE;
                        end
                    end
                end

                ST_READ_ADDR: begin
                    o_busy <= 1'b1;

                    if (r_axi_arvalid && w_axi_arready) begin
                        r_axi_arvalid <= 1'b0;
                        r_axi_rready  <= 1'b1;
                        r_state       <= ST_READ_DATA;
                    end
                end

                ST_READ_DATA: begin
                    o_busy <= 1'b1;

                    if (r_axi_rready && w_axi_rvalid) begin
                        r_axi_rready <= 1'b0;
                        o_rdata      <= w_axi_rdata;
                        o_resp       <= w_axi_rresp;
                        o_error      <= (w_axi_rresp != 2'b00) || r_init_error;
                        o_done       <= 1'b1;
                        o_busy       <= 1'b0;
                        r_state      <= ST_IDLE;
                    end
                end

                default: begin
                    r_state <= ST_BOOT_RESET;
                end
            endcase
        end
    end

    axi_quad_spi_0 spi_core_inst (
        .ext_spi_clk   (i_spi_clk),
        .s_axi_aclk    (clk),
        .s_axi_aresetn (w_axi_resetn),
        .s_axi_awaddr  (r_axi_awaddr),
        .s_axi_awvalid (r_axi_awvalid),
        .s_axi_awready (w_axi_awready),
        .s_axi_wdata   (r_axi_wdata),
        .s_axi_wstrb   (r_axi_wstrb),
        .s_axi_wvalid  (r_axi_wvalid),
        .s_axi_wready  (w_axi_wready),
        .s_axi_bresp   (w_axi_bresp),
        .s_axi_bvalid  (w_axi_bvalid),
        .s_axi_bready  (r_axi_bready),
        .s_axi_araddr  (r_axi_araddr),
        .s_axi_arvalid (r_axi_arvalid),
        .s_axi_arready (w_axi_arready),
        .s_axi_rdata   (w_axi_rdata),
        .s_axi_rresp   (w_axi_rresp),
        .s_axi_rvalid  (w_axi_rvalid),
        .s_axi_rready  (r_axi_rready),
        .io0_i         (qspi_io0_i),
        .io0_o         (qspi_io0_o),
        .io0_t         (qspi_io0_t),
        .io1_i         (qspi_io1_i),
        .io1_o         (qspi_io1_o),
        .io1_t         (qspi_io1_t),
        .io2_i         (qspi_io2_i),
        .io2_o         (qspi_io2_o),
        .io2_t         (qspi_io2_t),
        .io3_i         (qspi_io3_i),
        .io3_o         (qspi_io3_o),
        .io3_t         (qspi_io3_t),
        .ss_i          (qspi_ss_i),
        .ss_o          (qspi_ss_o),
        .ss_t          (qspi_ss_t),
        .cfgclk        (qspi_cfgclk),
        .cfgmclk       (qspi_cfgmclk),
        .eos           (qspi_eos),
        .preq          (qspi_preq),
        .ip2intc_irpt  (qspi_irq)
    );

endmodule
