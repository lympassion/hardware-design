`include "defines.v"

module mem(

	input wire										rst,

	input wire[`RegBus]          mem_pc_i,
	output wire[`RegBus]         mem_pc_o,
	
	//来自执行阶段的信息	
	input wire[`RegAddrBus]       wd_i,
	input wire                    wreg_i,
	input wire[`RegBus]					  wdata_i,
	
	// 数据加载  
	input wire[`AluOpBus]        aluop_i,
	input wire[`RegBus]          mem_addr_i,
	input wire[`RegBus]          reg2_i,
	input wire[`RegBus]          mem_data_i,//来自memory的信息
	output reg[`RegBus]          mem_addr_o,//送到memory的信息
	output wire					 mem_we_o,  // 是否是写操作，为1表示是写操作字节选择信号
	output reg[3:0]              mem_sel_o,  // 字节选择信号
	output reg[`RegBus]          mem_data_o, //  要写入的数据
	output reg                   mem_ce_o,	// 数据存储器的数据数据存储器使能信号
	// 其中只要是store或者load指令，mem_ce_o都为1，表示要访存
	// 只有当store指令时，mem_we_o才为1


	// Hilo寄存器添加的接口
	input wire                    whilo_i,
	input wire[`RegBus]           hi_i,
	input wire[`RegBus]           lo_i,
	output reg                    whilo_o,
	output reg[`RegBus]           hi_o,
	output reg[`RegBus]           lo_o,

	// mfc0, mtc0
	input wire                   cp0_reg_we_i,
	input wire[4:0]              cp0_reg_write_addr_i,
	input wire[`RegBus]          cp0_reg_data_i,
	output reg                   cp0_reg_we_o,
	output reg[4:0]              cp0_reg_write_addr_o,
	output reg[`RegBus]          cp0_reg_data_o,

	// 内陷特权
	input wire[31:0]             excepttype_i,
	input wire                   is_in_delayslot_i,
	input wire[`RegBus]          cp0_status_i,
	input wire[`RegBus]          cp0_cause_i,
	input wire[`RegBus]          cp0_epc_i,
 	input wire                    wb_cp0_reg_we,  // 写回阶段对cp0的前推
	input wire[4:0]               wb_cp0_reg_write_addr,
	input wire[`RegBus]           wb_cp0_reg_data,
	output reg[31:0]             excepttype_o,
	output wire[`RegBus]          cp0_epc_o,
	output wire                  is_in_delayslot_o,

	input  wire                  pcFalse_i,
	// badaddr中存的值
	output reg[`RegBus]           bad_addr_o,

	//送到回写阶段的信息
	output reg[`RegAddrBus]      wd_o,
	output reg                   wreg_o,
	output reg[`RegBus]					 wdata_o
	
);


	assign mem_pc_o = mem_pc_i;
	
	//写使能信号 在always里面 
	reg mem_we;
	assign mem_we_o = mem_we & (~(|excepttype_o)) ; // 这里再加入了异常处理之后需要增强判断条件(精确异常)

	//这里再加入了异常处理之后需要增强判断条件(精确异常)
	//改sel
	always @(*) begin
		if((|excepttype_o)==1) begin
			mem_sel_o <= 4'b0000;
		end
		else begin
			mem_sel_o <= mem_sel_o;
		end
	end

	reg[`RegBus]          cp0_status;
	reg[`RegBus]          cp0_cause;
	reg[`RegBus]          cp0_epc;



	// 内陷特权
	// 分别获取状态寄存器的最新值
	always @ (*) begin
		if(rst == `RstEnable) begin
			cp0_status <= `ZeroWord;
		end else if((wb_cp0_reg_we == `WriteEnable) && 
								(wb_cp0_reg_write_addr == `CP0_REG_STATUS ))begin
			cp0_status <= wb_cp0_reg_data;
		end else begin
		  cp0_status <= cp0_status_i;
		end
	end
	
	always @ (*) begin
		if(rst == `RstEnable) begin
			cp0_epc <= `ZeroWord;
		end else if((wb_cp0_reg_we == `WriteEnable) && 
								(wb_cp0_reg_write_addr == `CP0_REG_EPC ))begin
			cp0_epc <= wb_cp0_reg_data;
		end else begin
		  cp0_epc <= cp0_epc_i;
		end
	end

 	always @ (*) begin
		if(rst == `RstEnable) begin
			cp0_cause <= `ZeroWord;
		end else if((wb_cp0_reg_we == `WriteEnable) && 
								(wb_cp0_reg_write_addr == `CP0_REG_CAUSE ))begin
			cp0_cause[9:8] <= wb_cp0_reg_data[9:8];
			cp0_cause[22] <= wb_cp0_reg_data[22];
			cp0_cause[23] <= wb_cp0_reg_data[23];
		end else begin
		  cp0_cause <= cp0_cause_i;
		end
	end
	assign cp0_epc_o = cp0_epc;
	assign is_in_delayslot_o = is_in_delayslot_i;
	// 给出最终的异常类型
	always @ (*) begin
		if(rst == `RstEnable) begin
			excepttype_o <= `ZeroWord;
			bad_addr_o   <= `ZeroWord;
		end else begin
			excepttype_o <= `ZeroWord;
			bad_addr_o   <= `ZeroWord;
			
			if(mem_pc_o != `ZeroWord) begin
				if(((cp0_cause[15:8] & (cp0_status[15:8])) != 8'h00) && (cp0_status[1] == 1'b0) && 
							(cp0_status[0] == 1'b1)) begin
					excepttype_o <= 32'h00000001;        //interrupt
				end else if(excepttype_i[8] == 1'b1) begin
			  		excepttype_o <= 32'h00000008;        //syscall
				end else if(excepttype_i[9] == 1'b1) begin
					excepttype_o <= 32'h0000000a;        //inst_invalid
				end else if(excepttype_i[10] ==1'b1) begin
					excepttype_o <= 32'h0000000d;        //trap
				end else if(excepttype_i[11] == 1'b1) begin  //ov
					excepttype_o <= 32'h0000000c;
				end else if(excepttype_i[12] == 1'b1) begin  //返回指令
					excepttype_o <= 32'h0000000e;
				end else if(excepttype_i[13] == 1'b1) begin  //break指令
					excepttype_o <= 32'h00000009;
				end else if(excepttype_i[15] == 1'b1) begin  //badaddr_read_fetch指令
					excepttype_o <= 32'h00000004;
					if(pcFalse_i) begin
						bad_addr_o <= mem_pc_i;
					end else begin
						bad_addr_o <= mem_addr_i;
					end
				end else if(excepttype_i[14] == 1'b1) begin  //badaddr_write指令
					excepttype_o <= 32'h00000005;
					bad_addr_o <= mem_addr_i;
				end
			end
				
		end
	end		


	always @ (*) begin
		if(rst == `RstEnable) begin
			wd_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
		 	wdata_o <= `ZeroWord;

			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
		 	lo_o <= `ZeroWord;
			mem_addr_o <= `ZeroWord;
		    mem_we <= `WriteDisable;
		    mem_sel_o <= 4'b0000;
		    mem_data_o <= `ZeroWord;
		    mem_ce_o <= `ChipDisable;

			// mfc0, mtc0
			cp0_reg_we_o <= `WriteDisable;
			cp0_reg_write_addr_o <= 5'b00000;
			cp0_reg_data_o <= `ZeroWord;
		end else begin
		  	wd_o <= wd_i;
			wreg_o <= wreg_i;
			wdata_o <= wdata_i;

			whilo_o <= whilo_i;
			hi_o <= hi_i;
		 	lo_o <= lo_i;
			mem_we <= `WriteDisable;
			mem_addr_o <= `ZeroWord;
			mem_sel_o <= 4'b1111;
			mem_ce_o <= `ChipDisable; // 这里要换成小端模式

			// mfc0, mtc0
			cp0_reg_we_o <= cp0_reg_we_i;
			cp0_reg_write_addr_o <= cp0_reg_write_addr_i;
			cp0_reg_data_o <= cp0_reg_data_i;
			case (aluop_i)
				`EXE_LB_OP: begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteDisable;
					mem_ce_o <= `ChipEnable;
					case (mem_addr_i[1:0]) 
						2'b00: begin
							wdata_o <= {{24{mem_data_i[7]}},mem_data_i[7:0]};
							// mem_sel_o <= 4'b1000; 这里只要是load就要全为0（ip核）
							mem_sel_o <= 4'b0000;
						end
						2'b01:	begin
							wdata_o <= {{24{mem_data_i[15]}},mem_data_i[15:8]};
							// mem_sel_o <= 4'b0100;
							mem_sel_o <= 4'b0000;
						end
						2'b10:	begin
							wdata_o <= {{24{mem_data_i[23]}},mem_data_i[23:16]};
							// mem_sel_o <= 4'b0010;
							mem_sel_o <= 4'b0000;
						end
						2'b11:	begin
							wdata_o <= {{24{mem_data_i[31]}},mem_data_i[31:24]};
							// mem_sel_o <= 4'b0001;
							mem_sel_o <= 4'b0000;
						end
						default:	begin
							wdata_o <= `ZeroWord;
						end
					endcase
				end
				`EXE_LBU_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteDisable;
					mem_ce_o <= `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							wdata_o <= {{24{1'b0}},mem_data_i[7:0]};
							// mem_sel_o <= 4'b1000;
							mem_sel_o <= 4'b0000;
						end
						2'b01:	begin
							wdata_o <= {{24{1'b0}},mem_data_i[15:8]};
							// mem_sel_o <= 4'b0100;
							mem_sel_o <= 4'b0000;
						end
						2'b10:	begin
							wdata_o <= {{24{1'b0}},mem_data_i[23:16]};
							// mem_sel_o <= 4'b0010;
							mem_sel_o <= 4'b0000;
						end
						2'b11:	begin
							
							wdata_o <= {{24{1'b0}},mem_data_i[31:24]};
							// mem_sel_o <= 4'b0001;
							mem_sel_o <= 4'b0000;
						end
						default:	begin
							wdata_o <= `ZeroWord;
						end
					endcase				
				end
				`EXE_LH_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteDisable;
					mem_ce_o <= `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							wdata_o <= {{16{mem_data_i[15]}},mem_data_i[15:0]};
							// mem_sel_o <= 4'b1100;
							mem_sel_o <= 4'b0000;
						end
						2'b10:	begin
							wdata_o <= {{16{mem_data_i[31]}},mem_data_i[31:16]};
							// mem_sel_o <= 4'b0011;
							mem_sel_o <= 4'b0000;
						end
						default:	begin
							wdata_o <= `ZeroWord;
						end
					endcase					
				end
				`EXE_LHU_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteDisable;
					mem_ce_o <= `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							wdata_o <= {{16{1'b0}},mem_data_i[15:0]};
							// mem_sel_o <= 4'b1100;
							mem_sel_o <= 4'b0000;
						end
						2'b10:	begin
							wdata_o <= {{16{1'b0}},mem_data_i[31:16]};
							// mem_sel_o <= 4'b0011;
							mem_sel_o <= 4'b0000;
						end
						default:	begin
							wdata_o <= `ZeroWord;
						end
					endcase				
				end
				`EXE_LW_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteDisable;
					wdata_o <= mem_data_i;
					// mem_sel_o <= 4'b1111;
					mem_sel_o <= 4'b0000;
					mem_ce_o <= `ChipEnable;		
				end
				`EXE_SB_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteEnable;
					mem_data_o <= {reg2_i[7:0],reg2_i[7:0],reg2_i[7:0],reg2_i[7:0]};  // 没改
					mem_ce_o <= `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							mem_sel_o <= 4'b0001;
						end
						2'b01:	begin
							mem_sel_o <= 4'b0010;
						end
						2'b10:	begin
							mem_sel_o <= 4'b0100;
						end
						2'b11:	begin
							mem_sel_o <= 4'b1000;	
						end
						default:	begin
							mem_sel_o <= 4'b0000;
						end
					endcase				
				end
				`EXE_SH_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteEnable;
					mem_data_o <= {reg2_i[15:0],reg2_i[15:0]};
					mem_ce_o <= `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							mem_sel_o <= 4'b0011;
						end
						2'b10:	begin
							mem_sel_o <= 4'b1100;
						end
						default:	begin
							mem_sel_o <= 4'b0000;
						end
					endcase						
				end
				`EXE_SW_OP:		begin
					mem_addr_o <= mem_addr_i;
					mem_we <= `WriteEnable;
					mem_data_o <= reg2_i;
					mem_sel_o <= 4'b1111;	
					mem_ce_o <= `ChipEnable;		
				end
				default:		begin
          //什么也不做
				end
			endcase
		end    //if
	end      //always
			

endmodule