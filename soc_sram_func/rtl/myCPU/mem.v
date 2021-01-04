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

	//送到回写阶段的信息
	output reg[`RegAddrBus]      wd_o,
	output reg                   wreg_o,
	output reg[`RegBus]					 wdata_o
	
);


	assign mem_pc_o = mem_pc_i;
	
	//写使能信号 在always里面 
	reg mem_we;
	assign mem_we_o = mem_we ;

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