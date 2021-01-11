`include "defines.v"

module ctrl(

input wire						 rst,
input wire clk,
input wire stall_i,

	input wire                   stallreq_from_id,
	
	// 内陷特权
	input wire[31:0]             excepttype_i,
	input wire[`RegBus]          cp0_epc_i,
	output reg[`RegBus]          new_pc,
	output reg                   flush, 

  //来自执行阶段的暂停请求
	input wire                   stallreq_from_ex,
	output reg[5:0]              stall  // 注意这里的定义是大端    

);
	always @ (negedge clk) begin
		if (rst) begin
			stall <= 6'b0;
			flush <= 1'b0;
			new_pc <= `ZeroWord;
		end 
		else if (stall_i==1) begin
			stall <= 6'b011111;
		end
		else if(excepttype_i != `ZeroWord) begin
			flush <= 1'b1;
			stall <= 6'b000000;
			case (excepttype_i)
				32'h00000001, 32'h00000004, 32'h00000005, 32'h00000008, 32'h00000009,
				32'h0000000a, 32'h0000000d, 32'h0000000c: begin   
					new_pc <= 32'hbfc00380;
				end
				32'h0000000e:		begin   //eret
					new_pc <= cp0_epc_i;
				end
				default	: begin
				end
			endcase 						
		end else if(stallreq_from_ex == `Stop) begin // 注意ex，id的顺序
			stall <= 6'b001111;
			flush <= 1'b0;		
		end else if(stallreq_from_id == `Stop) begin
			stall <= 6'b000111;	
			flush <= 1'b0;		
		end else begin
			stall <= 6'b000000;
			flush <= 1'b0;
			new_pc <= `ZeroWord;		
		end    //if
	end      //always

endmodule