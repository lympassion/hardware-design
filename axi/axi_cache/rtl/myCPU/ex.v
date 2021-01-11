`include "defines.v"

module ex(

	input wire										rst,

	input wire[`RegBus]           ex_pc_i,
	output wire[`RegBus]          ex_pc_o,
	
	//送到执行阶段的信息
	input wire[`AluOpBus]         aluop_i,
	input wire[`AluSelBus]        alusel_i,
	input wire[`RegBus]           reg1_i,  // 对应的寄存器中读出来的数据
	input wire[`RegBus]           reg2_i,
	input wire[`RegAddrBus]       wd_i,    // 写到寄存器的地址
	input wire                    wreg_i,  // 是否写

	//是否转移、以及link address
	input wire[`RegBus]           link_address_i,
	input wire                    is_in_delayslot_i,  // 这个暂时没有用

	// 内陷特权
	input wire[31:0]              excepttype_i, // 译码阶段传过来的异常信息
	output wire[31:0]             excepttype_o,
	output wire                   is_in_delayslot_o, // 执行阶段是否是延迟槽指令

	// 数据加载
	input wire[`RegBus]          inst_i,
	output reg[`AluOpBus]        aluop_o,
	output reg[`RegBus]          mem_addr_o,
	output reg[`RegBus]          reg2_o,

	// 因为数据移动指令(HILO)而添加的接口
	input wire[`RegBus]			  hi_i,  // 对应Hilo寄存器的值
	input wire[`RegBus]			  lo_i,
	input wire                    mem_whilo_i,  // 处于访存阶段的指令是不是要写Hilo
	input wire[`RegBus]			  mem_hi_i,  // 访存阶段要写入hi寄存器的值
	input wire[`RegBus]			  mem_lo_i,  // 访存阶段要写入lo寄存器的值
	input wire                    wb_whilo_i,  // 处于写回阶段的指令是不是要写Hilo
	input wire[`RegBus]			  wb_hi_i,  // 写回阶段要写入hi寄存器的值
	input wire[`RegBus]			  wb_lo_i,  // 写回阶段要写入lo寄存器的值
	output reg                    whilo_o,  // 是否要写Hilo
	output reg[`RegBus]			  hi_o,  // 写入hi的值 
	output reg[`RegBus]			  lo_o,  // 写入lo的值


	// 增加了cpo寄存器后增加的
  	input wire                    mem_cp0_reg_we,  //访存阶段的指令是否要写CP0，用来检测数据相关
	input wire[4:0]               mem_cp0_reg_write_addr,
	input wire[`RegBus]           mem_cp0_reg_data,  // 访存阶段要写入的寄存器的值（前推）
 	input wire                    wb_cp0_reg_we,  //回写阶段的指令是否要写CP0，用来检测数据相关
	input wire[4:0]               wb_cp0_reg_write_addr,
	input wire[`RegBus]           wb_cp0_reg_data,  // 写回阶段要写入的寄存器的值（前推）
	output reg                    cp0_reg_we_o,  //向下一流水级传递写CP0中的寄存器信号
	output reg[4:0]               cp0_reg_write_addr_o,
	output reg[`RegBus]           cp0_reg_data_o,  // 执行阶段要向cp0传输的数据
	output reg                    pcFalse_o,
	// 直接与cp0相连的两个端口
	input wire[`RegBus]           cp0_reg_data_i,  //读取的CP0寄存器的值
	output reg[4:0]               cp0_reg_read_addr_o,  // 所读取的cp0寄存器的地址， 



	//除法模块添加的信号
	input wire[`DoubleRegBus]     div_result_i,
	input wire                    div_ready_i,
	output reg                    stallreq,
	output reg[`RegBus]           div_opdata1_o,
	output reg[`RegBus]           div_opdata2_o,
	output reg                    div_start_o,
	output reg                    signed_div_o,


	output reg[`RegAddrBus]       wd_o,
	output reg                    wreg_o,
	output reg[`RegBus]			  wdata_o
	
);

	assign ex_pc_o = ex_pc_i;

	reg[`RegBus] logicres;  // 保留逻辑运算结果
	reg[`RegBus] shiftres;  // 保留移位运算结果
	reg[`RegBus] Hilores;  // 保留数据移动指令(HILO)运算结果, 加入mfc0, mtco
	reg[`RegBus] arithmetic_sum_res;  // 保留加减运算结果
	reg[`DoubleRegBus] arithmetic_mult_res;;  // 保留乘法运算结果

	// reg[`RegBus] shiftzerores;  // 保留movn和movz两条指令的结果
	reg[`RegBus] HI;
	reg[`RegBus] LO;


	// arithmetic
	//add,sub
	wire[`RegBus]        reg2_i_subtoadd;  // 减法转为加法
	wire[`RegBus]        sumres;     // 加减得到的结果
	wire                 ov_flow;    // 是否溢出(加减)
	// slt
	wire[`RegBus]        reg1_lt_reg2;  
	//乘法 参考ppt
	wire[`RegBus]        mult_1;
	wire[`RegBus]        mult_2;
	wire[`DoubleRegBus]  mult_res;
	// 除法
	reg                  stallreq_for_div;


	// reg[`RegBus]         sltres;     // 加减得到的结果
	reg trapassert;  // 是否有自陷异常，在这里默认没有
	reg ovassert;    // 是否有溢出异常
	reg badaddr_read_fetch;// 自己加入
	reg badaddr_write;


	// 地址例外
	always @ (*) begin
		if(rst == `RstEnable) begin
			badaddr_read_fetch <= 0;
			badaddr_write <= 0;
			pcFalse_o       <= 0;
		end else begin
			badaddr_read_fetch <= 0;
			badaddr_write <= 0;
			pcFalse_o       <= 0;
			case (aluop_i)
				`EXE_LW_OP: begin
					if (mem_addr_o[1:0]!=2'b00) begin
						badaddr_read_fetch <= 1; 
					end
				end
				`EXE_LH_OP, `EXE_LHU_OP: begin
					if (mem_addr_o[1:0]!=2'b00 && mem_addr_o[1:0]!=2'b10) begin
						badaddr_read_fetch <= 1; 
					end
				end
				`EXE_SW_OP: begin
					if (mem_addr_o[1:0]!=2'b00) begin
						badaddr_write <= 1; 
					end
				end
				`EXE_SH_OP: begin
					if (mem_addr_o[1:0]!=2'b00 && mem_addr_o[1:0]!=2'b10) begin
						badaddr_write <= 1; 
					end
				end
				default: begin
					
				end 
			endcase
		 	if (ex_pc_o[1:0]!=2'b00) begin // pc
				 badaddr_read_fetch <= 1; 
				 pcFalse_o            <= 1;
			end 
	  	end
	end

	assign excepttype_o = {excepttype_i[31:16], badaddr_read_fetch, badaddr_write, excepttype_i[13:12],
								ovassert, trapassert,
  								excepttype_i[9:8],8'b0};

	// assign excepttype_o = {excepttype_i[31:12],ovassert,trapassert,excepttype_i[9:8],8'h00};


	// mfc0, mtco
	always @ (*) begin
		if(rst == `RstEnable) begin
			cp0_reg_we_o           <= 0;  //向下一流水级传递，用于写CP0中的寄存器
			cp0_reg_write_addr_o   <= `NOPRegAddr;
			cp0_reg_data_o         <= `ZeroWord;  // 执行阶段要向cp0传输的数据
			cp0_reg_read_addr_o    <= `NOPRegAddr;  // 所读取的cp0寄存器的地址	
			Hilores                <= `ZeroWord;						
		end else if(aluop_i == `EXE_MFC0_OP) begin  
			if(mem_cp0_reg_we && (mem_cp0_reg_write_addr == inst_i[15:11]) ) begin  // 这个地方一定要注意顺序(mem阶段的才是最新的)
				cp0_reg_read_addr_o <= inst_i[15:11];
				Hilores             <= mem_cp0_reg_data;
			end else if (wb_cp0_reg_we && (wb_cp0_reg_write_addr == inst_i[15:11]) ) begin
				cp0_reg_read_addr_o <= inst_i[15:11];
				Hilores      <= wb_cp0_reg_data;
			end else begin
				cp0_reg_read_addr_o <= inst_i[15:11];
				Hilores      <= cp0_reg_data_i;
			end
		end else if(aluop_i == `EXE_MTC0_OP) begin  
			cp0_reg_we_o           <= 1;
			cp0_reg_write_addr_o   <= inst_i[15:11];
			cp0_reg_data_o         <= reg1_i;  // 执行阶段要向cp0传输的数据
		end	else begin // 这里要有
			cp0_reg_write_addr_o <= 5'b00000;
			cp0_reg_we_o <= `WriteDisable;
			cp0_reg_data_o <= `ZeroWord;
		end		
	end
	

	// 数据加载
	always @ (*) begin
		if(rst == `RstEnable) begin
			aluop_o <= 8'b0;
			reg2_o <= `ZeroWord;
			mem_addr_o <= `ZeroWord;
			// inst_o <= 0;
		end else begin
		 	aluop_o <= aluop_i; // 用来确定加载或者存储的指令类型
			reg2_o <= reg2_i;  // 要(sw)存储的数据，或者是要(lw)将数据存储的寄存器地址
			mem_addr_o <= reg1_i + {{16{inst_i[15]}},inst_i[15:0]};  // load_store addr
	  end
	end
 


	// 逻辑运算
	always @ (*) begin
		if(rst == `RstEnable) begin
			logicres <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_AND_OP: begin
					logicres <= reg1_i & reg2_i;
				end
				`EXE_OR_OP:			begin
					logicres <= reg1_i | reg2_i;
				end
				`EXE_XOR_OP:			begin
					logicres <= reg1_i ^ reg2_i;
				end
				`EXE_NOR_OP:			begin
					logicres <= ~(reg1_i | reg2_i);
				end
				default:				begin
					logicres <= `ZeroWord;
				end
			endcase
		end    
	end

	// 移位运算
	always @ (*) begin
		if(rst == `RstEnable) begin
			shiftres <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_SLL_OP: begin
					// shiftres <= reg2_i << reg1_i;  // 默认用0填充
					shiftres <= reg2_i << reg1_i[4:0];  // 默认用0填充, 立即数的低五位
				end
				`EXE_SRL_OP:			begin
					// shiftres <= reg2_i >> reg1_i;
					shiftres <= reg2_i >> reg1_i[4:0];
				end
				`EXE_SRA_OP:			begin
					// shiftres <= ({32{reg2_i[31]}} << (6'd32-{1'b0, reg1_i[4:0]})) 
					// 							| reg2_i >> reg1_i[4:0];
					// shiftres <= ({32{reg2_i[31]}} << (~reg1_i[4:0]))  // 32-1，不可行
					// 							| reg2_i >> reg1_i[4:0];
					shiftres <= ($signed(reg2_i)) >>> reg1_i[4:0];
				end
				default:				begin
					shiftres <= `ZeroWord;
				end
			endcase
		end    
	end   


	// 读Hilo
	always @ (*) begin
		if(rst == `RstEnable) begin
			Hilores <= `ZeroWord;
		end else begin
			// whilo_o <= `WriteDisable;  // 默认不向Hilo寄存器写,向这一种写法在这里不可以可能受到干扰
			case (aluop_i)
				`EXE_MFHI_OP: begin
					whilo_o <= `WriteDisable;
					if(mem_whilo_i == 1'b1) begin
						hi_o <= mem_hi_i;
					end else if (wb_whilo_i == 1'b1) begin
						hi_o <= wb_hi_i;
					end else begin
						hi_o <= hi_i;
					end
					Hilores <= hi_o;
				end
				`EXE_MFLO_OP:			begin
					whilo_o <= `WriteDisable;
					// if(wb_whilo_i == 1'b1) begin  // 就是这个顺序写反了, 
					// 	lo_o <= wb_lo_i;
					// end else if (mem_whilo_i == 1'b1) begin
					// 	lo_o <= mem_lo_i;
					// end else begin
					// 	lo_o <= lo_i;
					// end
					if(mem_whilo_i == 1'b1) begin
						lo_o <= mem_lo_i;
					end else if (wb_whilo_i == 1'b1) begin
						lo_o <= wb_lo_i;
					end else begin
						lo_o <= lo_i;
					end
					Hilores <= lo_o;
				end
				// 首先要解决数据相关问题,这样写的MTHI，MTLO指令
				// 会产生一个问题,因为写Hilo寄存器是同时写的
				// 就是当需要写Hilo寄存器的时候,导致没有写的寄存器中的值变为x
				// `EXE_MTHI_OP:			begin 
				// 	whilo_o <= `WriteEnable;
				// 	hi_o <= reg1_i;
				// 	// Hilores <= hi_o;
				// end
				// `EXE_MTLO_OP:			begin
				// 	whilo_o <= `WriteEnable;
				// 	lo_o <= reg1_i;
				// 	// Hilores <= lo_o;
				// end
				`EXE_MOVZ_OP:		begin
					Hilores <= reg1_i;
				end
				`EXE_MOVN_OP:		begin
					Hilores <= reg1_i;
				end
				default:				begin
					// Hilores <= `ZeroWord;  // 这
				end
			endcase
		end    
	end   
	
	
	//得到最新的HI、LO寄存器的值，此处要解决指令数据相关问题
	always @ (*) begin
		if(rst == `RstEnable) begin
			{HI,LO} <= {`ZeroWord,`ZeroWord};
		end else if(mem_whilo_i == `WriteEnable) begin
			{HI,LO} <= {mem_hi_i,mem_lo_i};
		end else if(wb_whilo_i == `WriteEnable) begin
			{HI,LO} <= {wb_hi_i,wb_lo_i};
		end else begin
			{HI,LO} <= {hi_i,lo_i};			
		end
	end	


	// 写Hilo
	always @ (*) begin
		if(rst == `RstEnable) begin
			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
			lo_o <= `ZeroWord;		
		end else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
			whilo_o <= `WriteEnable;
			hi_o <= arithmetic_mult_res[63:32];
			lo_o <= arithmetic_mult_res[31:0];
		end  else if((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP)) begin
			whilo_o <= `WriteEnable;
			hi_o <= div_result_i[63:32];
			lo_o <= div_result_i[31:0];							
		end else if(aluop_i == `EXE_MTHI_OP) begin  //hilo_reg.v里面要写都写,所以这里要这样处理
			whilo_o <= `WriteEnable;
			hi_o <= reg1_i;  // 这里首先通过reg1_i得到rs的值
			lo_o <= LO;
		end else if(aluop_i == `EXE_MTLO_OP) begin
			whilo_o <= `WriteEnable;
			hi_o <= HI;
			lo_o <= reg1_i; // 这里首先通过reg1_i得到rs的值
		end else begin
			whilo_o <= `WriteDisable;
			hi_o <= `ZeroWord;
			lo_o <= `ZeroWord;
		end				
	end


	// movn和movz两条指令
	// always @ (*) begin
	// 	if(rst == `RstEnable) begin
	// 		shiftzerores <= `ZeroWord;
	// 	end else begin
	// 		// whilo_o <= `WriteDisable; 
	// 		case (aluop_i)
	// 			`EXE_MOVN_OP: begin
	// 				shiftzerores <= reg1_i;
	// 			end 
	// 			`EXE_MOVZ_OP: begin
	// 				shiftzerores <= reg1_i;
	// 			end
	// 			default:				begin
	// 				shiftzerores <= reg1_i;
	// 			end
	// 		endcase
	// 	end    
	// end     


	// arithmetic
	// 加减
	assign reg2_i_subtoadd = ((aluop_i==`EXE_SUB_OP) || (aluop_i==`EXE_SUBU_OP) ||(aluop_i==`EXE_SLT_OP))
							 ? (~(reg2_i)+1) : reg2_i; //这几条指令对应的sumres是减法运算的结果
	assign sumres = reg1_i + reg2_i_subtoadd;
	// 溢出情况,reg1_i与reg2_isubtoadd符号相同且运算结果相反
	assign ov_flow = ((reg1_i[31] == reg2_i_subtoadd[31]) && (sumres[31] != reg1_i[31])) &&
						((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || //可能产生溢出的指令
	      				(aluop_i == `EXE_SUB_OP));

	// slt
	assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP)) ?  // 
						((reg1_i[31] && !reg2_i[31]) || // 负数 正数
						(!reg1_i[31] && !reg2_i[31] && sumres[31])|| //同号的时候做减法就不用考虑溢出
						(reg1_i[31] && reg2_i[31] && sumres[31]))
						:	(reg1_i < reg2_i);
	//mult,multu 
	assign mult_1 = ((aluop_i == `EXE_MULT_OP) && reg1_i[31]) ? (~reg1_i + 1) : reg1_i;
	assign mult_2 = ((aluop_i == `EXE_MULT_OP) && reg2_i[31]) ? (~reg2_i + 1) : reg2_i;
	// 同号相乘,无符号乘法不需要修正
	assign mult_res = ((aluop_i == `EXE_MULT_OP) && (reg1_i[31] ^ reg2_i[31])) ? 
						(~(mult_1 * mult_2)+1) : mult_1 * mult_2; 

	
	// 溢出异常处理相关——具体在最后面处理写的模块
	// assign excepttype_o = {excepttype_i[31:12],ovassert,trapassert,excepttype_i[9:8],8'h00};
	// assign excepttype_o = {excepttype_i[31:12],ovassert,trapassert,excepttype_i[9:8],8'h00};

	assign is_in_delayslot_o = is_in_delayslot_i;
	// 
	always @ (*) begin
		if(rst == `RstEnable) begin
			arithmetic_mult_res <= `ZeroWord;
			arithmetic_sum_res <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_ADD_OP, `EXE_ADDI_OP, `EXE_ADDU_OP, `EXE_ADDIU_OP, `EXE_SUB_OP, `EXE_SUBU_OP: begin
					arithmetic_sum_res <= sumres;
				end
				`EXE_SLT_OP, `EXE_SLTU_OP:begin
					arithmetic_sum_res <= reg1_lt_reg2;
				end
				`EXE_MULT_OP, `EXE_MULTU_OP:begin
					arithmetic_mult_res <= mult_res;
				end
				default:				begin
					arithmetic_mult_res <= `ZeroWord;
					arithmetic_sum_res <= `ZeroWord;
				end
			endcase
		end    
	end
	
	always @ (*) begin
    	stallreq = stallreq_for_div;
  	end

   //DIV、DIVU指令	
	always @ (*) begin
		if(rst == `RstEnable) begin
			stallreq_for_div <= `NoStop;
	   		div_opdata1_o <= `ZeroWord;
			div_opdata2_o <= `ZeroWord;
			div_start_o <= `DivStop;
			signed_div_o <= 1'b0;
		end else begin
			stallreq_for_div <= `NoStop;
	    	div_opdata1_o <= `ZeroWord;
			div_opdata2_o <= `ZeroWord;
			div_start_o <= `DivStop;
			signed_div_o <= 1'b0;	
			case (aluop_i) 
				`EXE_DIV_OP:		begin
					if(div_ready_i == `DivResultNotReady) begin  // not----0
	    				div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStart;  // 1
						signed_div_o <= 1'b1;
						stallreq_for_div <= `Stop;
					end else if(div_ready_i == `DivResultReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStop;  // 0
						signed_div_o <= 1'b1;
						stallreq_for_div <= `NoStop;
					end else begin						
	    			div_opdata1_o <= `ZeroWord;
						div_opdata2_o <= `ZeroWord;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `NoStop;
					end					
				end
				`EXE_DIVU_OP:		begin
					if(div_ready_i == `DivResultNotReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStart;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `Stop;
					end else if(div_ready_i == `DivResultReady) begin
	    			div_opdata1_o <= reg1_i;
						div_opdata2_o <= reg2_i;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `NoStop;
					end else begin						
	    			div_opdata1_o <= `ZeroWord;
						div_opdata2_o <= `ZeroWord;
						div_start_o <= `DivStop;
						signed_div_o <= 1'b0;
						stallreq_for_div <= `NoStop;
					end					
				end
				default: begin
				end
			endcase
		end
	end	

	// 分支跳转
	always @ (*) begin
		if(rst == `RstEnable) begin
			logicres <= `ZeroWord;
		end else begin
			case (aluop_i)
				`EXE_AND_OP: begin
					logicres <= reg1_i & reg2_i;
				end
				`EXE_OR_OP:			begin
					logicres <= reg1_i | reg2_i;
				end
				`EXE_XOR_OP:			begin
					logicres <= reg1_i ^ reg2_i;
				end
				`EXE_NOR_OP:			begin
					logicres <= ~(reg1_i | reg2_i);
				end
				default:				begin
					logicres <= `ZeroWord;
				end
			endcase
		end    
	end


	// 这一模块处理写
	always @ (*) begin
		wd_o <= wd_i;
		trapassert <= `TrapNotAssert;
		// badaddr_read_fetch <= `TrapNotAssert;
		// badaddr_write <= `TrapNotAssert;
		if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || 
			(aluop_i == `EXE_SUB_OP)) && (ov_flow == 1'b1)) begin
			wreg_o <= `WriteDisable;
			ovassert <= 1'b1;
		end else begin
			wreg_o <= wreg_i;
			ovassert <= 1'b0;
		end
		// if(ov_flow)begin // 加法,减法放到一起, addi,add,sub引起的溢出处理方法是不将结果写入到寄存器中
		// 	wreg_o <= `WriteDisable;
		// end	 else begin
		// 	wreg_o <= wreg_i;
		// end	 	
		case ( alusel_i ) 
		`EXE_RES_LOGIC:		begin
			wdata_o <= logicres;
		end
		`EXE_RES_SHIFT:		begin
			wdata_o <= shiftres;
		end
		`EXE_RES_HILO:		begin
			wdata_o <= Hilores;
		end
		`EXE_RES_ARITHMETIC:begin
			wdata_o <= arithmetic_sum_res;
		end
		`EXE_RES_JUMP_BRANCH:	begin
	 		wdata_o <= link_address_i;
	 	end
		// `EXE_RES_MUL: begin
		// 	wdata_o <= arithmetic_mult_res[31:0];
		// end
		// `EXE_RES_ZERO:		begin  // 增加的movn和movz
		// 	wdata_o <= shiftzerores;
		// end
		default:					begin
			wdata_o <= `ZeroWord;
		end
		endcase
	end	

	

endmodule