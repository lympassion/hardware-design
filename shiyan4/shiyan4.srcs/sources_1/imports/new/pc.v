`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/07 16:33:00
// Design Name: 
// Module Name: pc
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


module pc(
    input clk,rst,
    input [31:0] din,
    output reg [31:0] q,
    output inst_ce
    );

    assign inst_ce = 1'b1;

    always@(posedge clk,posedge rst)
        if(rst) q <= 32'b0;
        else q <= din;
endmodule
