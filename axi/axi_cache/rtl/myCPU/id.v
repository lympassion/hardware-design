`include "defines.v"

module id(  

	input wire					rst,
	input wire[`InstAddrBus]	pc_i,
	input wire[`InstBus]        inst_i,

	output wire[`RegBus]        id_pc_o,  // 数据通路图在这里之后有关pc的接口和书上不一�?

	//处于执行阶段的指令要写入的目的寄存器信息
	input wire					ex_wreg_i,  // 执行阶段是否要写寄存�?
	input wire[`RegBus]			ex_wdata_i, // 写的数据 
	input wire[`RegAddrBus]     ex_wd_i,    // 写到寄存器堆中的地址
	
	//处于访存阶段的指令要写入的目的寄存器信息
	input wire					mem_wreg_i, // 是否�?
	input wire[`RegBus]			mem_wdata_i,
	input wire[`RegAddrBus]     mem_wd_i,

	input wire[`RegBus]         reg1_data_i,
	input wire[`RegBus]         reg2_data_i,

	// 异常处理
	output wire[31:0]             excepttype_o, // 在id模块得到的异常信�?
  	// output wire[`RegBus]          current_inst_address_0,

	

	// 数据加载指令增加接口
	input wire[`AluOpBus]        ex_aluop_i, // �?测是否处于译码阶段的指令存在译码相关
	output wire[`RegBus]         inst_o,
	output wire                 stallreq,


	// 分支跳转指令增加的接�?
	input wire                    is_in_delayslot_i,  //这条在译码的时�?�发现为延迟槽指令，is_in_delayslot为true
	output reg                    next_inst_in_delayslot_o, // 现在处于译码的指令是分支跳转指令并且满足跳转条件
	output reg                    branch_flag_o,
	output reg[`RegBus]           branch_target_address_o,       
	output reg[`RegBus]           link_addr_o,  // �?要保存的返回地址
	output reg                    is_in_delayslot_o,

	//送到regfile的信�?
	output reg                  reg1_read_o, // 表示我们要不要读取寄存器中的�?
	output reg                  reg2_read_o,     
	output reg[`RegAddrBus]     reg1_addr_o,
	output reg[`RegAddrBus]     reg2_addr_o, 	 

	
	//送到执行阶段的信�?
	output reg[`AluOpBus]       aluop_o,
	output reg[`AluSelBus]      alusel_o,
	output reg[`RegBus]         reg1_o,  // reg1 读出来的�?
	output reg[`RegBus]         reg2_o,
	output reg[`RegAddrBus]     wd_o,  // 写的寄存器号
	output reg                  wreg_o
);

	assign id_pc_o = pc_i;
	// assign stallreq = 0; //这里暂时没有暂停请求

	wire[5:0] op = inst_i[31:26];    // ori指令只需要高六位即可判断指令类型
	wire[4:0] op2 = inst_i[10:6];
	wire[5:0] op3 = inst_i[5:0];     // 功能�?
	wire[4:0] op4 = inst_i[20:16];
	reg[`RegBus]	imm;
	reg instvalid;

	wire [`RegBus]shiftres_rt;

	// 分支跳转
	wire[`RegBus] pc_plus_8;
	wire[`RegBus] pc_plus_4; 
	wire[`RegBus] imm_sll2_signedext_b;  
	wire[27:0] imm_sll2_signedext_j;  // 注意这里的位�?
	
	assign pc_plus_4 = pc_i +4; //
	assign imm_sll2_signedext_b = {{14{inst_i[15]}}, inst_i[15:0], 2'b00 }; //32
	assign imm_sll2_signedext_j = {inst_i[25:0], 2'b00 }; //28

	// load相关问题
	reg stallreq_for_reg1_loadrelate;
  	reg stallreq_for_reg2_loadrelate;
	wire pre_inst_is_load;


	// 异常处理（第几位初始值为0�?
	// �?8bits------- 留给外部中断
	// �?8bit ------- 系统调用例外
	// �?9bit ------- 保留指令例外（无法译码）
	// �?10bit -------自陷异常例外（ex中）
	// �?11bit -------溢出异常例外（ex中）
	// �?12bit--------eret指令（异常返回指令）
	// �?13bit--------break指令（断点例外）
	// �?14bit--------地址错例外（写数据访存不对齐, ex中）
	// �?15bit--------地址错例外（取指pc或读数据访存不对�?, ex中）
	reg excepttype_is_syscall;
  	reg excepttype_is_eret;
	reg excepttype_is_break; //加入
	// reg excepttype_is_badaddr_read_fetch;// 自己加入
	// reg excepttype_is_badaddr_write;

	// 这里加入了break指令                                                 13
	// assign excepttype_o = {16'b0, badaddr_read_fetch, badaddr_write, 
	// 							excepttype_is_break, excepttype_is_eret,2'b0,
  	// 							instvalid, excepttype_is_syscall,8'b0};
	assign excepttype_o = {18'b0, excepttype_is_break, excepttype_is_eret,2'b0,
							instvalid, excepttype_is_syscall,8'b0};  // `InstValid-----0

	
	assign pc_plus_8 = pc_i + 8;
	assign pc_plus_4 = pc_i +4;
	assign imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00 };  
	assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
	assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
								(ex_aluop_i == `EXE_LBU_OP)||
								(ex_aluop_i == `EXE_LH_OP) ||
								(ex_aluop_i == `EXE_LHU_OP)||
								(ex_aluop_i == `EXE_LW_OP)) ? 1'b1 : 1'b0;


	assign inst_o = inst_i;
	//id_ex_in_delayslot
	always @ (*) begin
		if(rst == `RstEnable) begin
			is_in_delayslot_o <= 0;
			// inst_o <= 0;
		end else begin
		 	 is_in_delayslot_o <= is_in_delayslot_i;
	  end
	end


	// mfc0,mtc0
	// always @ (*) begin	
	// 	if (rst == `RstEnable) begin
	// 		aluop_o <= `EXE_NOP_OP;
	// 		alusel_o <= `EXE_RES_NOP;
	// 		wd_o <= `NOPRegAddr;
	// 		wreg_o <= `WriteDisable;
	// 		instvalid <= `InstValid;
	// 		reg1_read_o <= 1'b0;
	// 		reg2_read_o <= 1'b0;
	// 		reg1_addr_o <= `NOPRegAddr;
	// 		reg2_addr_o <= `NOPRegAddr;
	// 		imm <= 32'h0;	

	// 		link_addr_o <= `ZeroWord;
	// 		branch_target_address_o <= `ZeroWord;
	// 		branch_flag_o <= `NotBranch;
	// 		next_inst_in_delayslot_o <= `NotInDelaySlot;

	// 		// 异常处理
	// 		excepttype_is_syscall <= `False_v;
	// 		excepttype_is_eret <= `False_v;	
	// 		excepttype_is_break <= `False_v;
	// 		// excepttype_is_badaddr_read_fetch <= `False_v;	
	// 		// excepttype_is_badaddr_write <= `False_v;
	//   	end else begin
	// 		if(inst_i == `EXE_ERET) begin // 这个指令在哪个位置没有影�?
	// 			wreg_o <= `WriteDisable;		aluop_o <= `EXE_ERET_OP;
	// 			alusel_o <= `EXE_RES_NOP;   reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
	// 			instvalid <= `InstValid; excepttype_is_eret<= `True_v;				
	// 		end else if(inst_i[31:21] == 11'b01000000000 && 
	// 									inst_i[10:0] == 11'b00000000000) begin
	// 			aluop_o <= `EXE_MFC0_OP;
	// 			alusel_o <= `EXE_RES_HILO;
	// 			wd_o <= inst_i[20:16];   // 写到rt中�?�不是rs�?
	// 			wreg_o <= `WriteEnable;
	// 			instvalid <= `InstValid;	   
	// 			reg1_read_o <= 1'b0;
	// 			reg2_read_o <= 1'b0;		
	// 		end else if(inst_i[31:21] == 11'b01000000100 && 
	// 									inst_i[10:0] == 11'b00000000000) begin
	// 			aluop_o <= `EXE_MTC0_OP;
	// 			alusel_o <= `EXE_RES_NOP;
	// 			wreg_o <= `WriteDisable;
	// 			instvalid <= `InstValid;	   
	// 			reg1_read_o <= 1'b1;
	// 			reg1_addr_o <= inst_i[20:16];
	// 			reg2_read_o <= 1'b0;					
	// 		end
	// 	end
	// end


 
	always @ (*) begin	
		if (rst == `RstEnable) begin
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			wd_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
			instvalid <= `InstValid;
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			reg1_addr_o <= `NOPRegAddr;
			reg2_addr_o <= `NOPRegAddr;
			imm <= 32'h0;	

			link_addr_o <= `ZeroWord;
			branch_target_address_o <= `ZeroWord;
			branch_flag_o <= `NotBranch;
			next_inst_in_delayslot_o <= `NotInDelaySlot;
			// 异常处理
			excepttype_is_syscall <= `False_v;
			excepttype_is_eret <= `False_v;	
			excepttype_is_break <= `False_v;		
	  end else begin
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			wd_o <= inst_i[15:11];  // 默认位置
			wreg_o <= `WriteDisable;
			instvalid <= (inst_i == `ZeroWord) ? `InstValid :`InstInvalid;	   // 空指令默认为有效指令
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			reg1_addr_o <= inst_i[25:21];
			reg2_addr_o <= inst_i[20:16];		
			imm <= `ZeroWord;		

			link_addr_o <= `ZeroWord;
			branch_target_address_o <= `ZeroWord;
			branch_flag_o <= `NotBranch;
			next_inst_in_delayslot_o <= `NotInDelaySlot;	
			// 异常处理
			excepttype_is_syscall <= `False_v;
			excepttype_is_eret <= `False_v;	
			excepttype_is_break <= `False_v;
			case (op)
				`EXE_LB:			begin
		  			wreg_o <= `WriteEnable;		aluop_o <= `EXE_LB_OP;
		  			alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[20:16]; instvalid <= `InstValid;	
				end
				`EXE_LBU:			begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_LBU_OP;
					alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[20:16]; instvalid <= `InstValid;	
				end
				`EXE_LH:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LH_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[20:16]; instvalid <= `InstValid;	
				end
				`EXE_LHU:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LHU_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[20:16]; instvalid <= `InstValid;	
				end
				`EXE_LW:			begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_LW_OP;
					alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[20:16]; instvalid <= `InstValid;	
					// excepttype_is_badaddr_read_fetch <= () || (pc_i[1:0] != 2'b00)
				end
				`EXE_SB:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_SB_OP;
		  		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
		  		alusel_o <= `EXE_RES_LOAD_STORE; 
				end
				`EXE_SH:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_SH_OP;
		  		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
		  		alusel_o <= `EXE_RES_LOAD_STORE; 
				end
				`EXE_SW:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_SW_OP;
		  		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
		  		alusel_o <= `EXE_RES_LOAD_STORE; 
				end
				


				`EXE_SPECIAL_INST:		begin
					case (op2)
						5'b00000:			begin
							case (op3)
								`EXE_OR:	begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_OR_OP;
									alusel_o <= `EXE_RES_LOGIC; 	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
									end  
								`EXE_AND:	begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_AND_OP;
									alusel_o <= `EXE_RES_LOGIC;	  reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;	
									instvalid <= `InstValid;	
									end  	
								`EXE_XOR:	begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_XOR_OP;
									alusel_o <= `EXE_RES_LOGIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;	
									instvalid <= `InstValid;	
									end  				
								`EXE_NOR:	begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_NOR_OP;
									alusel_o <= `EXE_RES_LOGIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;	
									instvalid <= `InstValid;	
									end 
								`EXE_SLLV: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLL_OP;
								alusel_o <= `EXE_RES_SHIFT;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
								instvalid <= `InstValid;	
								end 
								`EXE_SRLV: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRL_OP;
								alusel_o <= `EXE_RES_SHIFT;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
								instvalid <= `InstValid;	
								end 					
								`EXE_SRAV: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRA_OP;
								alusel_o <= `EXE_RES_SHIFT;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
								instvalid <= `InstValid;			
								end			
								// `EXE_SYNC: begin
								// 	wreg_o <= `WriteDisable;		aluop_o <= `EXE_NOP_OP;
								// alusel_o <= `EXE_RES_NOP;		reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;
								// instvalid <= `InstValid;	
								// end

								//HILO操作
								`EXE_MFHI:	begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_MFHI_OP;
									alusel_o <= `EXE_RES_HILO; 	reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid;	
								end 
								`EXE_MFLO:	begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_MFLO_OP;
									alusel_o <= `EXE_RES_HILO; 	reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid;	
								end 
								`EXE_MTHI:	begin
									wreg_o <= `WriteDisable;  // 其实上面默认是不写的	
									aluop_o <= `EXE_MTHI_OP; 
									alusel_o <= `EXE_RES_HILO; 	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid;	
								end 
								`EXE_MTLO:	begin
									wreg_o <= `WriteDisable;		
									aluop_o <= `EXE_MTLO_OP;
									alusel_o <= `EXE_RES_HILO; 	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid;	
								end 

								`EXE_MOVN:	begin
									wreg_o <=  shiftres_rt ? `WriteEnable : `WriteDisable;		
									aluop_o <= `EXE_MOVN_OP;
									alusel_o <= `EXE_RES_HILO; 	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end
								`EXE_MOVZ:	begin
									wreg_o <=  !shiftres_rt ? `WriteEnable : `WriteDisable;			
									aluop_o <= `EXE_MOVZ_OP;
									alusel_o <= `EXE_RES_HILO; 	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end


								// 算术运算指令 加减乘除slt
								// add,addu,sub,subu
								`EXE_ADD: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_ADD_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end 
								`EXE_ADDU: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_ADDU_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end 
								`EXE_SUB: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SUB_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end 
								`EXE_SUBU: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SUBU_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end 

								//slt,sltu
								`EXE_SLT: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLT_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end 
								`EXE_SLTU: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLTU_OP;
									alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end 

								//mult,multu
								`EXE_MULT: begin
									wreg_o <= `WriteDisable;		aluop_o <= `EXE_MULT_OP;
									alusel_o <= `EXE_RES_MUL;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end
								`EXE_MULTU: begin
									wreg_o <= `WriteDisable;		aluop_o <= `EXE_MULTU_OP;
									alusel_o <= `EXE_RES_MUL;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
									instvalid <= `InstValid;	
								end

								//div,divu
								`EXE_DIV: begin  // 这里并没有设置alusle_o,为默认的
									wreg_o <= `WriteDisable;  // 由于div指令的结果是写到Hilo寄存�?	
									aluop_o <= `EXE_DIV_OP;
		  							reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
								end
								`EXE_DIVU: begin
									wreg_o <= `WriteDisable;		aluop_o <= `EXE_DIVU_OP;
		  							reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;
								end

								
								//jr, jalr
								`EXE_JR: begin
									wreg_o <= `WriteDisable;		aluop_o <= `EXE_JR_OP;
									alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid;
									link_addr_o <= `ZeroWord;
									branch_target_address_o <= reg1_o;  // 跳转地址就是rs对应寄存器中的�??
									branch_flag_o <= `Branch;
									next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
								end
								`EXE_JALR: begin
									wreg_o <= `WriteEnable;		aluop_o <= `EXE_JALR_OP;
									alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid;
									// wd_o <= 5'b11111;  
									wd_o <= inst_i[15:11];
									link_addr_o <= pc_i+8;
									branch_target_address_o <= reg1_o;  // 跳转地址就是rs对应寄存器中的�??
									branch_flag_o <= `Branch;
									next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
								end

								// syscall,break
								`EXE_SYSCALL: begin
									wreg_o <= `WriteDisable;		aluop_o <= `EXE_SYSCALL_OP;
									alusel_o <= `EXE_RES_NOP;   reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid; excepttype_is_syscall<= `True_v;
								end	
								`EXE_BREAK: begin
									wreg_o <= `WriteDisable;		aluop_o <= `EXE_BREAK_OP;
									alusel_o <= `EXE_RES_NOP;   reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
									instvalid <= `InstValid; excepttype_is_break<= `True_v;
								end	
								default:	begin
								end
							endcase
						end
						default: begin
						end
					endcase	
				end	


				
				// 这里的指令都�?要立即数扩展, 改变resx_read_o, wd_o的�??,
				`EXE_ORI:			begin                        //ORI指令
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_OR_OP;
					alusel_o <= `EXE_RES_LOGIC; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					imm <= {16'h0, inst_i[15:0]};		wd_o <= inst_i[20:16];
					instvalid <= `InstValid;	
				end
				`EXE_ANDI:			begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_AND_OP;
					alusel_o <= `EXE_RES_LOGIC;	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
						imm <= {16'h0, inst_i[15:0]};		wd_o <= inst_i[20:16];		  	
						instvalid <= `InstValid;	
					end	 	
				`EXE_XORI:			begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_XOR_OP;
					alusel_o <= `EXE_RES_LOGIC;	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
						imm <= {16'h0, inst_i[15:0]};		wd_o <= inst_i[20:16];		  	
						instvalid <= `InstValid;	
					end	 		
				`EXE_LUI:			begin  
					// 注意，这里把这个指令转换为了ori指令，所以wd_o想其他指令一样对应更换，又因为rs刚好�?
					// $0,对应他的值reg1_addr_o，所以不�?要在做其他修�?
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_OR_OP;
					alusel_o <= `EXE_RES_LOGIC; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					imm <= {inst_i[15:0], 16'h0};		wd_o <= inst_i[20:16];		  	
					instvalid <= `InstValid;	
					end		
				// `EXE_PREF:			begin
				// wreg_o <= `WriteDisable;		aluop_o <= `EXE_NOP_OP;
				// alusel_o <= `EXE_RES_NOP; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;	  	  	
				// 	instvalid <= `InstValid;	
				// end	
                
				// addi,addiu
				`EXE_ADDI: begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_ADDI_OP;
					imm <= {{16{inst_i[15]}}, inst_i[15:0]};		wd_o <= inst_i[20:16];
					alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;	
				end 
				`EXE_ADDIU: begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_ADDIU_OP;
					imm <= {{16{inst_i[15]}}, inst_i[15:0]};		wd_o <= inst_i[20:16];
					alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;	
				end		
				`EXE_SLTI: begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLT_OP;  // 注意这个地方的aluop_o
					imm <= {{16{inst_i[15]}}, inst_i[15:0]};		wd_o <= inst_i[20:16];
					alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;	
				end 
				`EXE_SLTIU: begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLTU_OP;
					imm <= {{16{inst_i[15]}}, inst_i[15:0]};		wd_o <= inst_i[20:16];
					alusel_o <= `EXE_RES_ARITHMETIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;	
				end	
				
				// j,jal
				`EXE_J: begin
					wreg_o <= `WriteDisable;		aluop_o <= `EXE_J_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;
					link_addr_o <= `ZeroWord;
					branch_target_address_o <= {pc_plus_4[31:28], imm_sll2_signedext_j};  
					branch_flag_o <= `Branch;
					next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
				end
				`EXE_JAL: begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_JAL_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;   // reg1_read_o <= 1'b1;
					wd_o <= 5'b11111;  // 写入31号�?�用寄存�?
					link_addr_o <= pc_i+8;
					// branch_target_address_o <= {pc_i[3:0], imm_sll2_signedext_j}; 
					branch_target_address_o <= {pc_plus_4[31:28], imm_sll2_signedext_j}; 
					 
					branch_flag_o <= `Branch;
					next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
				end	
				//beq,bgtz, bgtz, blez, 这是有条件跳�?
				// `EXE_BEQ: begin
				// 	wreg_o <= `WriteDisable;		aluop_o <= `EXE_BEQ_OP;
				// 	alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
				// 	instvalid <= `InstValid;
				// 	branch_target_address_o <= pc_i + imm_sll2_signedext_b;  
				// 	branch_flag_o <= `Branch;
				// 	next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
				// end
				// `EXE_BGTZ: begin
				// 	wreg_o <= `WriteDisable;		aluop_o <= `EXE_BGTZ_OP;
				// 	alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
				// 	instvalid <= `InstValid;
				// 	branch_target_address_o <= pc_i + imm_sll2_signedext_b;  
				// 	branch_flag_o <= `Branch;
				// 	next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
				// end
				// `EXE_BLEZ: begin
				// 	wreg_o <= `WriteDisable;		aluop_o <= `EXE_BLEZ_OP;
				// 	alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
				// 	instvalid <= `InstValid;
				// 	branch_target_address_o <= pc_i + imm_sll2_signedext_b;  
				// 	branch_flag_o <= `Branch;
				// 	next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
				// end
				// `EXE_BNE: begin
				// 	wreg_o <= `WriteDisable;		aluop_o <= `EXE_BLEZ_OP;
				// 	alusel_o <= `EXE_RES_JUMP_BRANCH;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
				// 	instvalid <= `InstValid;
				// 	branch_target_address_o <= pc_i + imm_sll2_signedext_b;  
				// 	branch_flag_o <= `Branch;
				// 	next_inst_in_delayslot_o <= `InDelaySlot; // 这一条指令是跳转指令，那么下�?条指令就是延迟槽指令
				// end

				`EXE_BEQ:			begin
					wreg_o <= `WriteDisable;		aluop_o <= `EXE_BEQ_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
					instvalid <= `InstValid;	
					next_inst_in_delayslot_o <= `InDelaySlot;
					if(reg1_o == reg2_o) begin
						branch_target_address_o <= pc_plus_4+ imm_sll2_signedext_b;
						branch_flag_o <= `Branch;
						// next_inst_in_delayslot_o <= `InDelaySlot;		  	
					end
				end
				`EXE_BGTZ:			begin
					wreg_o <= `WriteDisable;		aluop_o <= `EXE_BGTZ_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;	
					next_inst_in_delayslot_o <= `InDelaySlot;		  	
					if((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord)) begin
						branch_target_address_o <= pc_plus_4+ imm_sll2_signedext_b;
						branch_flag_o <= `Branch;
						// next_inst_in_delayslot_o <= `InDelaySlot;		  	
					end
				end
				`EXE_BLEZ:			begin
					wreg_o <= `WriteDisable;		aluop_o <= `EXE_BLEZ_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
					instvalid <= `InstValid;	
					next_inst_in_delayslot_o <= `InDelaySlot;		  	
					if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord)) begin
						branch_target_address_o <= pc_plus_4+ imm_sll2_signedext_b;
						branch_flag_o <= `Branch;
						// next_inst_in_delayslot_o <= `InDelaySlot;		  	
					end
				end
				`EXE_BNE:			begin
					wreg_o <= `WriteDisable;		aluop_o <= `EXE_BLEZ_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
					instvalid <= `InstValid;	
					next_inst_in_delayslot_o <= `InDelaySlot;		  	
					if(reg1_o != reg2_o) begin
						branch_target_address_o <= pc_plus_4+ imm_sll2_signedext_b;
						branch_flag_o <= `Branch;
						// next_inst_in_delayslot_o <= `InDelaySlot;		  	
					end
				end

				`EXE_REGIMM_INST:		begin
					case (op4)
						`EXE_BGEZ:	begin
							wreg_o <= `WriteDisable;		aluop_o <= `EXE_BGEZ_OP;
							alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
							instvalid <= `InstValid;
							next_inst_in_delayslot_o <= `InDelaySlot;		  	
							if(reg1_o[31] == 1'b0) begin
								branch_target_address_o <= pc_plus_4 + imm_sll2_signedext_b;
								branch_flag_o <= `Branch;
								// next_inst_in_delayslot_o <= `InDelaySlot;		  	
							end
						end
						`EXE_BGEZAL:		begin
							wreg_o <= `WriteEnable;		aluop_o <= `EXE_BGEZAL_OP;
							alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
							link_addr_o <= pc_plus_8; 
							wd_o <= 5'b11111;  	instvalid <= `InstValid;
							next_inst_in_delayslot_o <= `InDelaySlot;
							if(reg1_o[31] == 1'b0) begin
								branch_target_address_o <= pc_plus_4 + imm_sll2_signedext_b;
								branch_flag_o <= `Branch;
								// next_inst_in_delayslot_o <= `InDelaySlot;
							end
						end
						`EXE_BLTZ:		begin
							wreg_o <= `WriteDisable;		aluop_o <= `EXE_BGEZAL_OP;
							alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
							instvalid <= `InstValid;	
							next_inst_in_delayslot_o <= `InDelaySlot;		  	
							if(reg1_o[31] == 1'b1) begin
								branch_target_address_o <= pc_plus_4 + imm_sll2_signedext_b;
								branch_flag_o <= `Branch;
								// next_inst_in_delayslot_o <= `InDelaySlot;		  	
							end
						end
						`EXE_BLTZAL:		begin
							wreg_o <= `WriteEnable;		aluop_o <= `EXE_BGEZAL_OP;
							alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
							link_addr_o <= pc_plus_8;	
							wd_o <= 5'b11111; instvalid <= `InstValid;
							next_inst_in_delayslot_o <= `InDelaySlot;
							if(reg1_o[31] == 1'b1) begin  // 小于0
								branch_target_address_o <= pc_plus_4 + imm_sll2_signedext_b;
								branch_flag_o <= `Branch;
								// next_inst_in_delayslot_o <= `InDelaySlot;
							end
						end
						default:	begin
						end
					endcase
				end	
				default:			begin
				end
		  	endcase		  //case op
		  
			if (inst_i[31:21] == 11'b00000000000) begin  // 对于sll,sra,srl指令来说
				if (op3 == `EXE_SLL) begin
					wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLL_OP;
					alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;	  	
						imm[4:0] <= inst_i[10:6];		wd_o <= inst_i[15:11];
						instvalid <= `InstValid;	
				end else if ( op3 == `EXE_SRL ) begin
				wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRL_OP;
				alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;	  	
					imm[4:0] <= inst_i[10:6];		wd_o <= inst_i[15:11];
					instvalid <= `InstValid;	
				end else if ( op3 == `EXE_SRA ) begin
				wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRA_OP;
				alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b0;	reg2_read_o <= 1'b1;	  	
					imm[4:0] <= inst_i[10:6];		wd_o <= inst_i[15:11];
					instvalid <= `InstValid;	
				end
			end

			// 要把mtc0和mfc0指令移进来，否则会判断这两个指令为无效指令，导致异常发生�?
		// 	if(inst_i == `EXE_ERET) begin // 这个指令在哪个位置没有影�?
		// 		wreg_o <= `WriteDisable;		aluop_o <= `EXE_ERET_OP;
		// 		alusel_o <= `EXE_RES_NOP;   reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
		// 		instvalid <= `InstValid; excepttype_is_eret<= `True_v;				
		// 	end else if(inst_i[31:21] == 11'b01000000000 && 
		// 								inst_i[10:0] == 11'b00000000000) begin
		// 		aluop_o <= `EXE_MFC0_OP;
		// 		alusel_o <= `EXE_RES_HILO;
		// 		wd_o <= inst_i[20:16];   // 写到rt中�?�不是rs�?
		// 		wreg_o <= `WriteEnable;
		// 		instvalid <= `InstValid;	   
		// 		reg1_read_o <= 1'b0;
		// 		reg2_read_o <= 1'b0;		
		// 	end else if(inst_i[31:21] == 11'b01000000100 && 
		// 								inst_i[10:0] == 11'b00000000000) begin
		// 		aluop_o <= `EXE_MTC0_OP;
		// 		alusel_o <= `EXE_RES_NOP;
		// 		wreg_o <= `WriteDisable;
		// 		instvalid <= `InstValid;	   
		// 		reg1_read_o <= 1'b1;
		// 		reg1_addr_o <= inst_i[20:16];
		// 		reg2_read_o <= 1'b0;					
		// 	end
		// end       //if

		if(inst_i == `EXE_ERET) begin
				wreg_o <= `WriteDisable;		aluop_o <= `EXE_ERET_OP;
		  	alusel_o <= `EXE_RES_NOP;   reg1_read_o <= 1'b0;	reg2_read_o <= 1'b0;
		  	instvalid <= `InstValid; excepttype_is_eret<= `True_v;				
			end else if(inst_i[31:21] == 11'b01000000000 && 
										inst_i[10:0] == 11'b00000000000) begin
				aluop_o <= `EXE_MFC0_OP;
				alusel_o <= `EXE_RES_HILO;
				wd_o <= inst_i[20:16];
				wreg_o <= `WriteEnable;
				instvalid <= `InstValid;	   
				reg1_read_o <= 1'b0;
				reg2_read_o <= 1'b0;		
			end else if(inst_i[31:21] == 11'b01000000100 && 
										inst_i[10:0] == 11'b00000000000) begin
				aluop_o <= `EXE_MTC0_OP;
				alusel_o <= `EXE_RES_NOP;
				wreg_o <= `WriteDisable;
				instvalid <= `InstValid;	   
				reg1_read_o <= 1'b1;
				reg1_addr_o <= inst_i[20:16];
				reg2_read_o <= 1'b0;					
			end
		  
		end       //if
	end         //always
	



	always @ (*) begin
		stallreq_for_reg1_loadrelate <= `NoStop;
		if(rst == `RstEnable) begin
			reg1_o <= `ZeroWord;
		end else if (pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o 
								&& reg1_read_o == 1'b1) begin
			stallreq_for_reg1_loadrelate <= 1;
			
		// 数据前推（回写的那个前推在regfile.v中解决了—�?�先读后写）
		end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) 
								&& (ex_wd_i == reg1_addr_o)) begin
			reg1_o <= ex_wdata_i; 
		end else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) 
								&& (mem_wd_i == reg1_addr_o)) begin
			reg1_o <= mem_wdata_i;
		
		end else if(reg1_read_o == 1'b1) begin
			reg1_o <= reg1_data_i;
		end else if(reg1_read_o == 1'b0) begin
			reg1_o <= imm;
		end else begin
			reg1_o <= `ZeroWord;
		end
		
	end
	
	
	always @ (*) begin
		stallreq_for_reg2_loadrelate <= `NoStop;
		if(rst == `RstEnable) begin
			reg2_o <= `ZeroWord;
		end else if (pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o 
								&& reg2_read_o == 1'b1) begin  //这里通过是否读确定load相关，那前面译码的时候不�?要读的时候就不要�?
			stallreq_for_reg2_loadrelate <= 1;
		end else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1)  // 数据前推
								&& (ex_wd_i == reg2_addr_o)) begin
			reg2_o <= ex_wdata_i; 
		end else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) 
								&& (mem_wd_i == reg2_addr_o)) begin
			reg2_o <= mem_wdata_i;

		end else if(reg2_read_o == 1'b1) begin
			reg2_o <= reg2_data_i;
		end else if(reg2_read_o == 1'b0) begin
			reg2_o <= imm;
		end else begin
			reg2_o <= `ZeroWord;
		end
	end

	assign shiftres_rt = reg2_o;

endmodule