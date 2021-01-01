`include "defines.v"

module mem_wb(

	input	wire										clk,
	input wire										rst,
	
	//
	input wire[5:0]              stall,

	//来自访存阶段的信息	
	input wire[`RegAddrBus]       mem_wd,
	input wire                    mem_wreg,
	input wire[`RegBus]					 mem_wdata,

	// Hilo寄存器添加的接口
	input wire                    mem_whilo,
	input wire[`RegBus]           mem_hi,
	input wire[`RegBus]           mem_lo,
	output reg                    wb_whilo,
	output reg[`RegBus]           wb_hi,
	output reg[`RegBus]           wb_lo,

	//送到回写阶段的信息
	output reg[`RegAddrBus]      wb_wd,
	output reg                   wb_wreg,
	output reg[`RegBus]					 wb_wdata	       
	
);


	always @ (posedge clk) begin
		if((rst == `RstEnable) || (stall[4] == 1 && stall[5] == 0))begin
			wb_wd <= `NOPRegAddr;
			wb_wreg <= `WriteDisable;
		    wb_wdata <= `ZeroWord;	

			wb_whilo <= 0;
			wb_hi <= `ZeroWord;
			wb_lo <= `ZeroWord;
		end else begin
			wb_wd <= mem_wd;
			wb_wreg <= mem_wreg;
			wb_wdata <= mem_wdata;

			wb_whilo <= mem_whilo;
			wb_hi <= mem_hi;
			wb_lo <= mem_lo;
		end    //if
	end      //always
			

endmodule