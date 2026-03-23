`timescale 1ns/1ps

module tb_bram_only;

    reg         clk = 0;
    reg         rst = 0;

    reg  [8:0]  rdaddr = 0;
    reg         rden   = 0;
    wire [31:0] dout;

    reg  [8:0]  wraddr = 0;
    reg  [31:0] di     = 0;
    reg  [3:0]  we     = 0;
    reg         wren   = 0;

    always #5 clk = ~clk;

    BRAM_SDP_MACRO #(
        .BRAM_SIZE("18Kb"),
        .DEVICE("7SERIES"),
        .WRITE_WIDTH(32),
        .READ_WIDTH(32),
        .DO_REG(0),
        .INIT_FILE("NONE"),
        .SIM_COLLISION_CHECK("ALL"),
        .SRVAL(72'h0),
        .INIT(72'h0),
        .WRITE_MODE("READ_FIRST"),

        .INIT_00(256'h0), .INIT_01(256'h0), .INIT_02(256'h0), .INIT_03(256'h0),
        .INIT_04(256'h0), .INIT_05(256'h0), .INIT_06(256'h0), .INIT_07(256'h0),
        .INIT_08(256'h0), .INIT_09(256'h0), .INIT_0A(256'h0), .INIT_0B(256'h0),
        .INIT_0C(256'h0), .INIT_0D(256'h0), .INIT_0E(256'h0), .INIT_0F(256'h0),
        .INIT_10(256'h0), .INIT_11(256'h0), .INIT_12(256'h0), .INIT_13(256'h0),
        .INIT_14(256'h0), .INIT_15(256'h0), .INIT_16(256'h0), .INIT_17(256'h0),
        .INIT_18(256'h0), .INIT_19(256'h0), .INIT_1A(256'h0), .INIT_1B(256'h0),
        .INIT_1C(256'h0), .INIT_1D(256'h0), .INIT_1E(256'h0), .INIT_1F(256'h0),
        .INIT_20(256'h0), .INIT_21(256'h0), .INIT_22(256'h0), .INIT_23(256'h0),
        .INIT_24(256'h0), .INIT_25(256'h0), .INIT_26(256'h0), .INIT_27(256'h0),
        .INIT_28(256'h0), .INIT_29(256'h0), .INIT_2A(256'h0), .INIT_2B(256'h0),
        .INIT_2C(256'h0), .INIT_2D(256'h0), .INIT_2E(256'h0), .INIT_2F(256'h0),
        .INIT_30(256'h0), .INIT_31(256'h0), .INIT_32(256'h0), .INIT_33(256'h0),
        .INIT_34(256'h0), .INIT_35(256'h0), .INIT_36(256'h0), .INIT_37(256'h0),
        .INIT_38(256'h0), .INIT_39(256'h0), .INIT_3A(256'h0), .INIT_3B(256'h0),
        .INIT_3C(256'h0), .INIT_3D(256'h0), .INIT_3E(256'h0), .INIT_3F(256'h0),

        .INITP_00(256'h0), .INITP_01(256'h0), .INITP_02(256'h0), .INITP_03(256'h0),
        .INITP_04(256'h0), .INITP_05(256'h0), .INITP_06(256'h0), .INITP_07(256'h0)
    ) dut (
        .DO(dout),
        .DI(di),
        .RDADDR(rdaddr),
        .RDCLK(clk),
        .RDEN(rden),
        .REGCE(1'b1),
        .RST(rst),
        .WE(we),
        .WRADDR(wraddr),
        .WRCLK(clk),
        .WREN(wren)
    );

    initial begin
        // escrita addr 0
        @(negedge clk);
        wraddr = 9'd0;
        di     = 32'hAABBCCDD;
        we     = 4'b1111;
        wren   = 1'b1;

        @(negedge clk);
        wren   = 1'b0;
        we     = 4'b0000;

        // escrita addr 1
        @(negedge clk);
        wraddr = 9'd1;
        di     = 32'h11223344;
        we     = 4'b1111;
        wren   = 1'b1;

        @(negedge clk);
        wren   = 1'b0;
        we     = 4'b0000;

        // leitura addr 0
        @(negedge clk);
        rdaddr = 9'd0;
        rden   = 1'b1;

        @(posedge clk);
        @(posedge clk);
        #1 $display("addr0 = %h", dout);

        // leitura addr 1
        @(negedge clk);
        rdaddr = 9'd1;

        @(posedge clk);
        @(posedge clk);
        #1 $display("addr1 = %h", dout);

        @(negedge clk);
        rden = 1'b0;

        #20;
        $finish;
    end

endmodule