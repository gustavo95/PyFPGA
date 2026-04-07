`timescale 1ns / 1ps

module debounce #(
    parameter integer COUNTER_WIDTH = 19
)(
    input  wire clk,
    input  wire i_btn,
    output reg  o_btn
);

    reg sync_0;
    reg sync_1;
    reg stable_state;
    reg [COUNTER_WIDTH-1:0] counter;

    wire w_same_state = (sync_1 == stable_state);
    wire w_counter_max = &counter;

    always @(posedge clk) begin
        sync_0 <= i_btn;
        sync_1 <= sync_0;

        if (w_same_state) begin
            counter <= {COUNTER_WIDTH{1'b0}};
        end else begin
            counter <= counter + 1'b1;

            if (w_counter_max) begin
                stable_state <= sync_1;
                o_btn        <= sync_1;
                counter      <= {COUNTER_WIDTH{1'b0}};
            end
        end
    end

    initial begin
        sync_0       = 1'b0;
        sync_1       = 1'b0;
        stable_state = 1'b0;
        counter      = {COUNTER_WIDTH{1'b0}};
        o_btn        = 1'b0;
    end

endmodule
