`include "defines.v"

module if_id(

	input wire					clk,
	input wire					rst,
	input wire[5:0]             stall,

	// 异常处理
	input wire                  flush, // 如果flush为1，则清除流水线

	input wire[`InstAddrBus]	if_pc,
	input wire[`InstBus]        if_inst,
	output reg[`InstAddrBus]    id_pc,
	output reg[`InstBus]        id_inst  
	
);

	always @ (posedge clk) begin
		if (rst == `RstEnable || (stall[1] == `Stop && stall[2] == `NoStop) || flush == 1) begin
			id_pc <= `ZeroWord;
			id_inst <= `ZeroWord;
		// end else if (stall[1] == 1) begin
		// 	id_pc <= id_pc;
		//  	id_inst <= id_inst;
		// end else begin
		// 	id_pc <= if_pc;
		// 	id_inst <= if_inst;
		// end
		end else if (stall[1] == 0) begin
			id_pc <= if_pc;
		 	id_inst <= if_inst;
		end 
	end

endmodule