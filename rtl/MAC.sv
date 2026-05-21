module MAC (
    input  logic clk,
    input  logic mac_reset,
    input  logic signed [13:0] A,               // 14-bit EIngang 1
    input  logic signed [31:0] B,               // 14-bit Eingang 2
    output logic signed [47:0] result           // 48-bit Akkumulatorausgang
);

xbip_dsp48_macro_0 mac_i (
    .CLK(clk),
    .SCLR(mac_reset),
    .A(A),   
    .B(B),    
    .P(result)
);

endmodule
