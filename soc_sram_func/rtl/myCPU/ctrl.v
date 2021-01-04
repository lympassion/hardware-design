`include "defines.v"

module ctrl(

input wire						 rst,

	input wire                   stallreq_from_id,

  //来自执行阶段的暂停请求
	input wire                   stallreq_from_ex,
	output reg[5:0]              stall  // 注意这里的定义是大端     
	
);
	always @ (*) begin
		if (rst) begin
			stall <= 6'b0;
		end else if (stallreq_from_id) begin
	 		stall <= 6'b0001_11; // 暂停id,if,pc
		end else if(stallreq_from_ex)begin
			stall <= 6'b0011_11; // 暂停ex,id,if,pc
		end else begin
			stall <= 6'b000_000;
		end
	end

endmodule