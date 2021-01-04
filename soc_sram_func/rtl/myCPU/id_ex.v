`include "defines.v"

module id_ex(

	input	wire										clk,
	input wire										rst,
	input wire[5:0]                    stall,

	input wire[`InstBus]         id2ex_pc_i,
	output reg[`RegBus]          id2ex_pc_o,
	
	//从译码阶段传递的信息
	input wire[`AluOpBus]         id_aluop,
	input wire[`AluSelBus]        id_alusel,
	input wire[`RegBus]           id_reg1,
	input wire[`RegBus]           id_reg2,
	input wire[`RegAddrBus]       id_wd,
	input wire                    id_wreg,	

	// 分支跳转指令添加的接口
	input wire[`RegBus]           id_link_address,
	input wire                    id_is_in_delayslot,
	input wire                    next_inst_in_delayslot_i,	
	output reg[`RegBus]           ex_link_address,
  	output reg                    ex_is_in_delayslot,
	output reg                    is_in_delayslot_o,

	// 数据加载
	input wire[`RegBus]           id_inst,		
	output reg[`RegBus]           ex_inst,	
	
	//传递到执行阶段的信息
	output reg[`AluOpBus]         ex_aluop,
	output reg[`AluSelBus]        ex_alusel,
	output reg[`RegBus]           ex_reg1,
	output reg[`RegBus]           ex_reg2,
	output reg[`RegAddrBus]       ex_wd,
	output reg                    ex_wreg
	
);

	always @ (posedge clk) begin  //000_111, 001_111
		if ((rst == `RstEnable) || (stall[2] == 1 && stall[3] == 0)) begin
			ex_aluop <= `EXE_NOP_OP;
			ex_alusel <= `EXE_RES_NOP;
			ex_reg1 <= `ZeroWord;
			ex_reg2 <= `ZeroWord;
			ex_wd <= `NOPRegAddr;
			ex_wreg <= `WriteDisable;

			ex_is_in_delayslot <= 0;
			ex_link_address <= `ZeroWord;
			is_in_delayslot_o <= 0;
			ex_inst <= `ZeroWord;
			id2ex_pc_o <= `ZeroWord;

		end else if(stall[2] == `NoStop)begin  // 这里一定要加这个判断条件, 否则这种情况001_111会更新
			ex_aluop <= id_aluop;
			ex_alusel <= id_alusel;
			ex_reg1 <= id_reg1;
			ex_reg2 <= id_reg2;
			ex_wd <= id_wd;
			ex_wreg <= id_wreg;

			ex_is_in_delayslot <= id_is_in_delayslot;
			ex_link_address <= id_link_address;
			is_in_delayslot_o <= next_inst_in_delayslot_i;	
			ex_inst <= 	id_inst;
			id2ex_pc_o <= id2ex_pc_i;
		end
	end

	
endmodule