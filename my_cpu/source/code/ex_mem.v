`include "defines.v"

module ex_mem(

	input	wire										clk,
	input wire										rst,
	input wire[5:0]               stall,
	
	//来自执行阶段的信息	
	input wire[`RegAddrBus]       ex_wd,
	input wire                    ex_wreg,
	input wire[`RegBus]					 ex_wdata, 	

	// Hilo寄存器添加的接口
	input wire                    ex_whilo,
	input wire[`RegBus]           ex_hi,
	input wire[`RegBus]           ex_lo,
	output reg                    mem_whilo,
	output reg[`RegBus]           mem_hi,
	output reg[`RegBus]           mem_lo,
	
	//送到访存阶段的信息
	output reg[`RegAddrBus]      mem_wd,
	output reg                   mem_wreg,
	output reg[`RegBus]			 mem_wdata
	
	
);


	always @ (posedge clk) begin
		if((rst == `RstEnable) || (stall[3] == 1 && stall[4] == 0))begin
			mem_wd <= `NOPRegAddr;
			mem_wreg <= `WriteDisable;
		  	mem_wdata <= `ZeroWord;
			
			mem_whilo <= 0;
			mem_hi <= `ZeroWord;
			mem_lo <= `ZeroWord;  

		end 
		else if(stall[3] == 0)begin
			mem_wd <= ex_wd;
			mem_wreg <= ex_wreg;
			mem_wdata <= ex_wdata;	

			mem_whilo <= ex_whilo;
			mem_hi <= ex_hi;
			mem_lo <= ex_lo;		
		end    //if
	end      //always
			

endmodule