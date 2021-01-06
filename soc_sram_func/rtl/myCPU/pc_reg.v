`include "defines.v"

module pc_reg(

	input wire            			clk,
	input wire						rst,
	
	// 分支跳转指令增加的接�?
	input wire                    branch_flag_i,
	input wire[`RegBus]           branch_target_address_i,  // 译码阶段给出的分支跳转地�?

	input wire[5:0]                 stall,

	// 异常处理增加的接口
	input wire                    flush,  // 流水线清除
	input wire[`RegBus]           new_pc,  // 异常处理地址

	output reg[`InstAddrBus]		pc,
	output reg                      ce  // pc 改变是使能端信号
	
);
	
	// always @ (posedge clk) begin  
	// 	if (ce == `ChipDisable) begin
	// 		pc <= 32'h00000000;
	// 	end else if(stall[0] == 0) begin
	// 	  		pc <= pc + 4'h4;
	// 	end
	// end
	
	always @ (posedge clk) begin  // 
		if (ce == `ChipDisable) begin
			//pc <= 32'h00000000;
			pc<=32'hbfc00000;
		end else if(flush == 1'b1) begin
			pc <= new_pc;
		end else if(stall[0] == 0) begin
			if (branch_flag_i == 1'b1) begin
				pc <= branch_target_address_i;
			end 
			else begin
				pc <= pc + 4'h4;
			end
		end 
	end

	always @ (posedge clk) begin
		if (rst == `RstEnable) begin
			ce <= `ChipDisable;
		end else begin
			ce <= `ChipEnable;
		end
	end

endmodule