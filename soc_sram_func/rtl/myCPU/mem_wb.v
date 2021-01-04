`include "defines.v"

module mem_wb(

	input	wire										clk,
	input wire										rst,
	
	input wire[`RegBus]         mem2wb_pc_i,
	output reg[`RegBus]         mem2wb_pc_o,

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

	// mfc0, mtc0
	input wire                   mem_cp0_reg_we,
	input wire[4:0]              mem_cp0_reg_write_addr,
	input wire[`RegBus]          mem_cp0_reg_data,
	output reg[4:0]              wb_cp0_reg_write_addr,
	output reg[`RegBus]          wb_cp0_reg_data,
	output reg                   wb_cp0_reg_we,

	//送到回写阶段的信息
	output reg[`RegAddrBus]      wb_wd,
	output reg                   wb_wreg,
	output reg[`RegBus]			 wb_wdata	       
	
);


	always @ (posedge clk) begin
		if((rst == `RstEnable) || (stall[4] == 1 && stall[5] == 0))begin
			wb_wd <= `NOPRegAddr;
			wb_wreg <= `WriteDisable;
		    wb_wdata <= `ZeroWord;	

			wb_whilo <= 0;
			wb_hi <= `ZeroWord;
			wb_lo <= `ZeroWord;
			mem2wb_pc_o <= `ZeroWord;

			// mfc0, mtc0
			wb_cp0_reg_we <= `WriteDisable;
			wb_cp0_reg_write_addr <= 5'b00000;
			wb_cp0_reg_data <= `ZeroWord;
		end else begin
			wb_wd <= mem_wd;
			wb_wreg <= mem_wreg;
			wb_wdata <= mem_wdata;

			wb_whilo <= mem_whilo;
			wb_hi <= mem_hi;
			wb_lo <= mem_lo;
			mem2wb_pc_o <= mem2wb_pc_i;

			// mfc0, mtc0
			wb_cp0_reg_we <= mem_cp0_reg_we;
			wb_cp0_reg_write_addr <= mem_cp0_reg_write_addr;
			wb_cp0_reg_data <= mem_cp0_reg_data;
		end    //if
	end      //always
			

endmodule