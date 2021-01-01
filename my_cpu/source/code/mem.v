`include "defines.v"

module mem(

	input wire										rst,
	
	//来自执行阶段的信息	
	input wire[`RegAddrBus]       wd_i,
	input wire                    wreg_i,
	input wire[`RegBus]					  wdata_i,
	
	// Hilo寄存器添加的接口
	input wire                    whilo_i,
	input wire[`RegBus]           hi_i,
	input wire[`RegBus]           lo_i,
	output reg                    whilo_o,
	output reg[`RegBus]           hi_o,
	output reg[`RegBus]           lo_o,

	//送到回写阶段的信息
	output reg[`RegAddrBus]      wd_o,
	output reg                   wreg_o,
	output reg[`RegBus]					 wdata_o
	
);

	
	always @ (*) begin
		if(rst == `RstEnable) begin
			wd_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
		 	wdata_o <= `ZeroWord;

			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
		 	lo_o <= `ZeroWord;
		end else begin
		  	wd_o <= wd_i;
			wreg_o <= wreg_i;
			wdata_o <= wdata_i;

			whilo_o <= whilo_i;
			hi_o <= hi_i;
		 	lo_o <= lo_i;
		end    //if
	end      //always
			

endmodule