`include "defines.v"

module ex_mem(

	input	wire										clk,
	input wire										rst,
	input wire[5:0]               stall,
	
	input wire[`InstBus]         ex2mem_pc_i,
	output reg[`RegBus]          ex2mem_pc_o,

	//来自执行阶段的信息	
	input wire[`RegAddrBus]       ex_wd,
	input wire                    ex_wreg,
	input wire[`RegBus]					 ex_wdata, 	

	//为实现加载、访存指令而添加
 	input wire[`AluOpBus]        ex_aluop,
	input wire[`RegBus]          ex_mem_addr,
	input wire[`RegBus]          ex_reg2,
	output reg[`AluOpBus]        mem_aluop,
	output reg[`RegBus]          mem_mem_addr,
	output reg[`RegBus]          mem_reg2,

	// Hilo寄存器添加的接口
	input wire                    ex_whilo,
	input wire[`RegBus]           ex_hi,
	input wire[`RegBus]           ex_lo,
	output reg                    mem_whilo,
	output reg[`RegBus]           mem_hi,
	output reg[`RegBus]           mem_lo,

	// mfc0,mtc0
	input wire                   ex_cp0_reg_we,
	input wire[4:0]              ex_cp0_reg_write_addr,
	input wire[`RegBus]          ex_cp0_reg_data,	// 要向cp0写的数据
	output reg                   mem_cp0_reg_we,
	output reg[4:0]              mem_cp0_reg_write_addr,
	output reg[`RegBus]          mem_cp0_reg_data,

	// 特权内陷增加的模块
	input wire                   flush,
	input wire[31:0]             ex_excepttype,
	input wire                   ex_is_in_delayslot,
	output reg[31:0]            mem_excepttype,
  	output reg                  mem_is_in_delayslot,
	input wire                  ex_pcFalse,
	output reg                  mem_pcFalse,
	
	//送到访存阶段的信息
	output reg[`RegAddrBus]      mem_wd,
	output reg                   mem_wreg,
	output reg[`RegBus]			 mem_wdata
	
	
);


	always @ (posedge clk) begin
		if((rst == `RstEnable) || (stall[3] == 1 && stall[4] == 0 ) || flush)begin
			mem_wd <= `NOPRegAddr;
			mem_wreg <= `WriteDisable;
		  	mem_wdata <= `ZeroWord;
			
			mem_whilo <= 0;
			mem_hi <= `ZeroWord;
			mem_lo <= `ZeroWord;  

			// 数据加载
			mem_aluop <= 8'b0;
			mem_mem_addr <= `ZeroWord;
			mem_reg2 <= `ZeroWord;
			ex2mem_pc_o <= `ZeroWord;

			//mfc0, mtc0
			mem_cp0_reg_we          <= 0;
			mem_cp0_reg_write_addr  <= 5'b00000;
			mem_cp0_reg_data        <= `ZeroWord;

			// 特权内陷
			mem_excepttype <= `ZeroWord;
  			mem_is_in_delayslot <= 0;

			mem_pcFalse    <= 0;
		end 
		else if(stall[3] == 0)begin
			mem_wd <= ex_wd;
			mem_wreg <= ex_wreg;
			mem_wdata <= ex_wdata;	

			mem_whilo <= ex_whilo;
			mem_hi <= ex_hi;
			mem_lo <= ex_lo;	

			// 数据加载
			mem_aluop <= ex_aluop;
			mem_mem_addr <= ex_mem_addr;
			mem_reg2 <= ex_reg2;	
			ex2mem_pc_o <= ex2mem_pc_i;

			// mfc0, mtc0
			mem_cp0_reg_we          <= ex_cp0_reg_we;
			mem_cp0_reg_write_addr  <= ex_cp0_reg_write_addr;
			mem_cp0_reg_data        <= ex_cp0_reg_data;

			// 特权内陷
			mem_excepttype <= ex_excepttype;
  			mem_is_in_delayslot <= ex_is_in_delayslot;

			mem_pcFalse    <= ex_pcFalse;
		end    
	end     
			

endmodule