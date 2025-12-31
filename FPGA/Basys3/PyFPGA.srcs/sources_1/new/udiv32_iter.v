module udiv32_iter (
    input  wire        CLK,
    input  wire        RESET,

    input  wire        start,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,

    output reg         busy,
    output reg         done,
    output reg  [31:0] quotient,
    output reg  [31:0] remainder,
    output reg         div0
);

    reg [31:0] a;          // shift register do dividendo
    reg [31:0] b;          // divisor
    reg [31:0] q;          // quociente em construção
    reg [32:0] r;          // resto (33 bits p/ comparação/sub)
    reg [5:0]  cnt;        // 32 passos
    reg calc_finished;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            busy      <= 1'b0;
            done      <= 1'b0;
            quotient  <= 32'd0;
            remainder <= 32'd0;
            div0      <= 1'b0;
            calc_finished <= 1'b0;

            a <= 32'd0;
            b <= 32'd0;
            q <= 32'd0;
            r <= 33'd0;
            cnt <= 6'd0;
        end else begin
            // start (aceita somente quando não está ocupado)
            if (start && !busy) begin
                div0 <= (divisor == 0);

                if (divisor == 0) begin
                    // define o que você quer fazer em div0 (aqui: zera tudo)
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    quotient  <= 32'd0;
                    remainder <= 32'd0;
                end else begin
                    busy <= 1'b1;

                    a <= dividend;
                    b <= divisor;
                    q <= 32'd0;
                    r <= 33'd0;
                    cnt <= 6'd32;
                end
            end
            else if (busy && !calc_finished) begin
                // 1 iteração por ciclo: "restoring division"
                // shift left resto e traz MSB do 'a'
                r <= {r[31:0], a[31]};
                a <= {a[30:0], 1'b0};

                // compara/subtrai
                if ({r[31:0], a[31]} >= {1'b0, b}) begin
                    r <= {r[31:0], a[31]} - {1'b0, b};
                    q <= {q[30:0], 1'b1};
                end else begin
                    q <= {q[30:0], 1'b0};
                end

                cnt <= cnt - 1'b1;

                if (cnt == 6'd1) begin
                    calc_finished <= 1'b1;
                end
            end
            else if (calc_finished) begin
                busy <= 1'b0;
                done <= 1'b1;
                calc_finished <= 1'b0;
                quotient <= q;
                remainder<= r[31:0];
            end
            else begin
                done <= 1'b0;
                calc_finished <= 1'b0;
            end
        end
    end

endmodule
