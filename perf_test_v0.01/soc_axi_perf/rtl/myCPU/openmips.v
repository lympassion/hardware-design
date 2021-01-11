`include "defines.v"

module openmips(

	input	wire										clk,
	input wire										resetn,
	input wire[5:0]                    int,
	input wire i_stall,
	input wire d_stall,
	output wire longest_stall,

	// 添加了datamem
	input wire[`RegBus]           data_sram_rdata, 
	output wire[`RegBus]          data_sram_addr,//送到memory的信息
	//output wire					 mem2datamem_we,  // 是否是写操作，为1表示是写操作字节选择信号(这里封装的ip核没有)
	output wire[3:0]              data_sram_wen,  // 字节选择信号
	output wire[`RegBus]          data_sram_wdata, //  要写入的数据
	output wire                   data_sram_en,	// 数据存储器的数据数据存储器使能信号
 
	input wire[`RegBus]           inst_sram_rdata,
	output wire[`RegBus]          inst_sram_addr,
	output wire                    inst_sram_en,
	//硬综添加接口
	//output wire[`RegBus] inst_sram_wdata,//写数据
	//output wire[3:0] inst_sram_wen,//指令存储器只读不写 恒为0000

	//debug模块
	output wire[31:0] debug_wb_pc,
	output wire[3:0] debug_wb_rf_wen,//回写使能  变成4bit
	output wire[4:0] debug_wb_rf_wnum,//回写的寄存器号
	output wire[31:0] debug_wb_rf_wdata//回写的目的操作数


	//连接data_ram
	// input wire[`RegBus]           ram_data_i,
	// output wire[`RegBus]           ram_addr_o,
	// output wire[`RegBus]           ram_data_o,
	// output wire                    ram_we_o,
	// output wire[3:0]               ram_sel_o,
	// output wire[3:0]               ram_ce_o

);	
	wire axi_stall;
	assign axi_stall = i_stall || d_stall ;
	// assign longest_stall = stallreq_from_ex_i || stallreq_from_id_i;
	assign longest_stall = |stall;

	// 参数定义说明
	// xx_o----->某一个模块的输出,如ex_wd_o表示ex模块的输出
	// xx_i----->某一个模块的输入,如ex_wd_i表示ex模块的输入

	//assign  inst_sram_wdata = `ZeroWord ;
	//assign  inst_sram_wen= 4'b0000;
	wire mem2datamem_we;//这是从mem传过来的 是否写 信号 但是传到data_rom模块没有这个接口 所以这里不输出到output
	wire timer_int_o;//这里也是硬综接口中的int_i 是直接6'b0  所以不需要这一个接口


	wire[`RegBus] data_sram_addr_temp;
	wire[`RegBus] inst_sram_addr_temp;

	// assign data_sram_addr = (data_sram_addr_temp[31] ==1'b1)? {3'b0,data_sram_addr_temp[28:0]} : data_sram_addr_temp;
	// assign inst_sram_addr = (inst_sram_addr_temp[31] ==1'b1)? {3'b0,inst_sram_addr_temp[28:0]} : inst_sram_addr_temp;  

    //IF/ID模块与译码阶段ID模块
	wire[`InstAddrBus] pc;
	wire[`InstAddrBus] id_pc_i;
	wire[`InstBus] id_inst_i;
	
	
	//连接译码阶段ID模块的输出与ID/EX模块的输入
	wire[`AluOpBus] id_aluop_o;
	wire[`AluSelBus] id_alusel_o;
	wire[`RegBus] id_reg1_o;
	wire[`RegBus] id_reg2_o;
	wire id_wreg_o;
	wire[`RegAddrBus] id_wd_o;
	wire[`RegBus]     id_pc;
	
	//连接ID/EX模块的输出与执行阶段EX模块的输入
	wire[`AluOpBus] ex_aluop_i;
	wire[`AluSelBus] ex_alusel_i;
	wire[`RegBus] ex_reg1_i;
	wire[`RegBus] ex_reg2_i;
	wire ex_wreg_i;
	wire[`RegAddrBus] ex_wd_i;
	wire[`RegBus] ex_inst;
	wire[`RegBus]     id2ex_pc;

	//id_ex到 id
	wire id2id_is_in_delayslot;

	

	//连接执行阶段EX模块的输出与EX/MEM模块的输入
	wire ex_wreg_o;
	wire[`RegAddrBus] ex_wd_o;
	wire[`RegBus] ex_wdata_o;
	wire[`RegBus] ex_pc;

	//Hilo
	wire ex_whilo_o;
	wire[`RegBus] ex_hi_o;
	wire[`RegBus] ex_lo_o;
	// 数据加载
	wire[`AluOpBus]        ex2id_mem_aluop;
	wire[`RegBus]          ex2mem_addr;
	wire[`RegBus]          ex2mem_reg2;



	//连接EX/MEM模块的输出与访存阶段MEM模块的输入
	wire mem_wreg_i;
	wire[`RegAddrBus] mem_wd_i;
	wire[`RegBus] mem_wdata_i;
	wire[`RegBus] ex2mem_pc;

	//Hilo
	wire mem_whilo_i;
	wire[`RegBus] mem_hi_i;
	wire[`RegBus] mem_lo_i;
	//为实现加载、访存指令而添加
	wire[`AluOpBus]        mem_aluop;
	wire[`RegBus]          mem_mem_addr;
	wire[`RegBus]          mem_reg2;

	//连接访存阶段MEM模块的输出与MEM/WB模块的输入
	wire mem_wreg_o;
	wire[`RegAddrBus] mem_wd_o;
	wire[`RegBus] mem_wdata_o;
	wire[`RegBus] mem_pc;
	//Hilo
	wire mem_whilo_o;
	wire[`RegBus] mem_hi_o;
	wire[`RegBus] mem_lo_o;

	
	//连接MEM/WB模块的输出与回写阶段的输入	
	wire[`RegBus] mem2wb_pc;
	wire wb_wreg_i;
	wire[`RegAddrBus] wb_wd_i;
	wire[`RegBus] wb_wdata_i;
	//连接MEM/WB模块与Hilo
	wire hilo_we_i;
	wire[`RegBus] hi_i;
	wire[`RegBus] lo_i;
	
	//连接译码阶段ID模块与通用寄存器Regfile模块
	wire reg1_read;
	wire reg2_read;
	wire[`RegBus] reg1_data;
	wire[`RegBus] reg2_data;
	wire[`RegAddrBus] reg1_addr;
	wire[`RegAddrBus] reg2_addr;

	//连接回写阶段HELO与执行阶段
	wire[`RegBus] hi_o;
	wire[`RegBus] lo_o;

	// ctrl 
	wire[5:0] stall;
	wire      stallreq_from_id_i;
	wire      stallreq_from_ex_i;

	//div
	wire[`DoubleRegBus] div_result_i; // 64位
	wire          div_ready_i;
	wire          signed_div_i;
	wire[`RegBus] div_opdata1_i;
	wire[`RegBus] div_opdata2_i;
	wire          div_start_i;

	// 分支跳转
	wire branch_flag;
	wire[`InstAddrBus]    branch_target_address;
	wire                  id2ex_is_in_delayslot;  //这条在译码的时候发现为延迟槽指令，is_in_delayslot为true
	wire                  next_inst_in_delayslot; // 现在处于译码的指令是分支跳转指令并且满足跳转条件     
	wire[`RegBus]         id_link_address;  // 需要保存的返回地址
	wire                  id_is_in_delayslot;
	wire[`RegBus]         ex_link_address;
	wire                  ex_is_in_delayslot;  // 这个暂时没有用

	// load相关增加的接口
	wire[`RegBus]      id_inst_o;

	// 异常处理增加的接口 
	wire[31:0]             mem2cp0_excepttype;
	wire[`RegBus]          mem2cp0_cp0_epc;
	wire[`RegBus]          cp02pc_new_pc;  // 异常处理地址
	wire                   	flush;
	wire[31:0]              id_excepttype;
	wire[31:0]              id2ex_excepttype;
	wire[31:0]             ex_excepttype;
	// wire                   ex_is_in_delayslot; // 执行阶段是否是延迟槽指令
	wire[31:0]             ex2mem_excepttype;
  	wire                   ex2mem_is_in_delayslot;
	wire[`RegBus]          cp02mem_cp0_status;
	wire[`RegBus]          cp02mem_cp0_cause;
	wire[`RegBus]          cp02mem_cp0_epc;
 	wire                    wb2mem_cp0_reg_we;  // 写回阶段对cp0的前推
	wire[4:0]               wb2mem_cp0_reg_write_addr;
	wire[`RegBus]           wb2mem_cp0_reg_data;
	// wire[31:0]             mem2cp0_excepttype;
	wire[`RegBus]          mem2ctrl_cp0_epc;
	wire                  mem2cp0_is_in_delayslot;
	wire[`RegBus]           mem2cp0_pc;
	wire[`RegBus]           cp02mem_status;
	wire[`RegBus]           cp02mem_cause;
	wire[`RegBus]           cp02mem_epc;

	wire                     ex_pcFalse;
	wire                     ex2mem_pcFalse;
	wire[`RegBus]             mem2cp0_bad_addr;



	wire[`RegBus]            cp02ex_data;
	
	wire                    ex_cp0_reg_we;  //向下一流水级传递写CP0中的寄存器信号
	wire[4:0]               ex_cp0_reg_write_addr;
	wire[`RegBus]           ex_cp0_reg_data;  // 执行阶段要向cp0传输的数据
	wire[4:0]               ex2cp0_cp0_reg_read_addr;  // 所读取的cp0寄存器的地址，

	wire                   ex2mem_cp0_reg_we;
	wire[4:0]              ex2mem_cp0_reg_write_addr;
	wire[`RegBus]          ex2mem_cp0_reg_data;

	wire                   mem_cp0_reg_we;
	wire[4:0]              mem_cp0_reg_write_addr;
	wire[`RegBus]          mem_cp0_reg_data;

	wire                   mem2cp0_cp0_reg_we;
	wire[4:0]              mem2cp0_cp0_reg_write_addr;
	wire[`RegBus]          mem2cp0_cp0_reg_data;


	//debug模块
	assign debug_wb_pc = mem2wb_pc;//这里不是使用的回写阶段的pc 后面需要修改
	assign debug_wb_rf_wen ={4{wb_wreg_i}};
	assign debug_wb_rf_wnum = wb_wd_i;
	assign debug_wb_rf_wdata= wb_wdata_i;

	wire[31:0] inst_paddr;
	wire[31:0] data_paddr;
	// mmu
	// mmu mmu(  // 保证从openmips(cpu)中出来的是物理地址
	// 	.inst_vaddr(inst_sram_addr_temp),
	// 	.inst_paddr(inst_paddr), // 映射之后的地址
	// 	.data_vaddr(data_sram_addr_temp),
	// 	.data_paddr(data_paddr)
	// );
	assign inst_sram_addr = inst_sram_addr_temp;
	assign data_sram_addr = data_sram_addr_temp;

  
  //pc_reg例化
	pc_reg pc_reg0(
		.clk(clk),
		.rst(resetn),

		// 分支跳转指令增加的接口
		.branch_flag_i(branch_flag),
		.branch_target_address_i(branch_target_address),

		// 异常处理增加的接口
		.flush(flush),  // 流水线清除
		.new_pc(cp02pc_new_pc),  // 异常处理地址

		.pc(pc),
		.stall(stall),
		.ce(inst_sram_en)	
	);
	
  assign inst_sram_addr_temp = pc;

  //通用寄存器Regfile例化
	regfile regfile1(
		.clk (clk),
		.rst (resetn),
		.we	(wb_wreg_i),  // 是否要写,最终信号传入寄存器堆
		.waddr (wb_wd_i),
		.wdata (wb_wdata_i),
		.re1 (reg1_read),
		.raddr1 (reg1_addr),
		.rdata1 (reg1_data),
		.re2 (reg2_read),
		.raddr2 (reg2_addr),
		.rdata2 (reg2_data)
	);

	hilo_reg hilo_reg0(
		.clk(clk),
		.rst(resetn),
		// 写
		.we(hilo_we_i),
		.hi_i(hi_i),
		.lo_i(lo_i),
		// 读
        .hi_o(hi_o),
        .lo_o(lo_o)
	);

	// div模块
	div div0(
		.clk(clk),
		.rst(resetn),
	
		.signed_div_i(signed_div_i),
		.opdata1_i(div_opdata1_i),
		.opdata2_i(div_opdata2_i),
		.start_i(div_start_i),
		.annul_i(1'b0),
	
		.result_o(div_result_i),
		.ready_o(div_ready_i)
	);

	ctrl ctrl0(
		.rst(resetn),
		.clk(clk),
		.stall_i(axi_stall),

		// 内陷特权
		.excepttype_i(mem2cp0_excepttype),
		.cp0_epc_i(mem2ctrl_cp0_epc),
		.new_pc(cp02pc_new_pc),
		.flush(flush), 

		.stallreq_from_id(stallreq_from_id_i),
		.stallreq_from_ex(stallreq_from_ex_i),
		.stall(stall)       	
	);

  //IF/ID模块例化
	if_id if_id0(
		.clk(clk),
		.rst(resetn),
		.flush(flush),
		.if_pc(pc),
		.stall(stall),
		.if_inst(inst_sram_rdata),
		.id_pc(id_pc_i),
		.id_inst(id_inst_i)      	
	);
	
	//译码阶段ID模块
	id id0(
		.rst(resetn),
		.pc_i(id_pc_i),
		.inst_i(id_inst_i),
		.id_pc_o(id_pc),

		// 数据加载指令增加接口
		.ex_aluop_i(ex2id_mem_aluop), // 检测是否处于译码阶段的指令存在译码相关
		.inst_o(id_inst_o),
		.stallreq(stallreq_from_id_i),

		// 内线特权
		.excepttype_o(id_excepttype),

		// 分支跳转指令增加的接口
		.is_in_delayslot_i(id2id_is_in_delayslot),  //这条在译码的时候发现为延迟槽指令，is_in_delayslot为true
		.next_inst_in_delayslot_o(next_inst_in_delayslot), // 现在处于译码的指令是分支跳转指令并且满足跳转条件
		.branch_flag_o(branch_flag),
		.branch_target_address_o(branch_target_address),       
		.link_addr_o(id_link_address),  // 需要保存的返回地址
		.is_in_delayslot_o(id_is_in_delayslot),

		//处于执行阶段的指令要写入的目的寄存器信息
		.ex_wreg_i(ex_wreg_o),
		.ex_wdata_i(ex_wdata_o),
		.ex_wd_i(ex_wd_o),
	
		//处于访存阶段的指令要写入的目的寄存器信息
		.mem_wreg_i(mem_wreg_o),
		.mem_wdata_i(mem_wdata_o),
		.mem_wd_i(mem_wd_o),

		.reg1_data_i(reg1_data),
		.reg2_data_i(reg2_data),

		//送到regfile的信息
		.reg1_read_o(reg1_read),
		.reg2_read_o(reg2_read), 	  

		.reg1_addr_o(reg1_addr),
		.reg2_addr_o(reg2_addr), 
	  	
		//送到ID/EX模块的信息
		.aluop_o(id_aluop_o),
		.alusel_o(id_alusel_o),
		.reg1_o(id_reg1_o),
		.reg2_o(id_reg2_o),
		.wd_o(id_wd_o),
		.wreg_o(id_wreg_o)
	);

	

	//ID/EX模块
	id_ex id_ex0(
		.clk(clk),
		.rst(resetn),
		.id2ex_pc_i(id_pc),
		.id2ex_pc_o(id2ex_pc),

		.id_link_address(id_link_address),
		.id_is_in_delayslot(id_is_in_delayslot),
		.next_inst_in_delayslot_i(next_inst_in_delayslot),	
		.ex_link_address(ex_link_address),
		.ex_is_in_delayslot(id2ex_is_in_delayslot),
		.is_in_delayslot_o(id2id_is_in_delayslot),

		// 数据加载添加的接口
		.id_inst(id_inst_o),		
		.ex_inst(ex_inst),

		// 内线特权
		.flush(flush),
		.id_excepttype(id_excepttype),
		.ex_excepttype(id2ex_excepttype),
		
		
		//从译码阶段ID模块传递的信息
		.id_aluop(id_aluop_o),
		.id_alusel(id_alusel_o),
		.id_reg1(id_reg1_o),
		.id_reg2(id_reg2_o),
		.id_wd(id_wd_o),
		.id_wreg(id_wreg_o),

		.stall(stall),
	
		//传递到执行阶段EX模块的信息
		.ex_aluop(ex_aluop_i),
		.ex_alusel(ex_alusel_i),
		.ex_reg1(ex_reg1_i),
		.ex_reg2(ex_reg2_i),
		.ex_wd(ex_wd_i),
		.ex_wreg(ex_wreg_i)
	);		
	
	//EX模块
	ex ex0(
		.rst(resetn),
		.ex_pc_i(id2ex_pc),
		.ex_pc_o(ex_pc),


		//送到执行阶段EX模块的信息
		.aluop_i(ex_aluop_i),
		.alusel_i(ex_alusel_i),
		.reg1_i(ex_reg1_i),
		.reg2_i(ex_reg2_i),
		.wd_i(ex_wd_i),
		.wreg_i(ex_wreg_i),

		// 内陷特权
		.excepttype_i(id2ex_excepttype), // 译码阶段传过来的异常信息
		.excepttype_o(ex_excepttype),
		.is_in_delayslot_o(ex_is_in_delayslot), // 执行阶段是否是延迟槽指令

		// 数据加载
		.inst_i(ex_inst),
		.aluop_o(ex2id_mem_aluop),
		.mem_addr_o(ex2mem_addr),
		.reg2_o(ex2mem_reg2),

		//是否转移、以及link address
		.link_address_i(ex_link_address),
		.is_in_delayslot_i(id2ex_is_in_delayslot),  // 这个暂时没有用

		// 因为数据移动指令(HILO)而添加的接口
		.hi_i(hi_o),  // 对应Hilo寄存器的值
		.lo_i(lo_o),
		.mem_whilo_i(mem_whilo_o),  // 处于访存阶段的指令是不是要写Hilo
		.mem_hi_i(mem_hi_o),  // 访存阶段要写入hi寄存器的值
		.mem_lo_i(mem_lo_o),  // 访存阶段要写入lo寄存器的值
		.wb_whilo_i(hilo_we_i),  // 处于写回阶段的指令是不是要写Hilo
		.wb_hi_i(hi_i),  // 写回阶段要写入hi寄存器的值
		.wb_lo_i(lo_i),  // 写回阶段要写入lo寄存器的值
		.whilo_o(ex_whilo_o),  // 是否要写Hilo
		.hi_o(ex_hi_o),  // 写入hi的值 
		.lo_o(ex_lo_o),  // 写入lo的值

		// 增加了cpo寄存器后增加的
		.mem_cp0_reg_we(mem_cp0_reg_we),  //访存阶段的指令是否要写CP0，用来检测数据相关
		.mem_cp0_reg_write_addr(mem_cp0_reg_write_addr),
		.mem_cp0_reg_data(mem_cp0_reg_data),  // 访存阶段要写入的寄存器的值（前推）
		.wb_cp0_reg_we(mem2cp0_cp0_reg_we),  //回写阶段的指令是否要写CP0，用来检测数据相关
		.wb_cp0_reg_write_addr(mem2cp0_cp0_reg_write_addr),
		.wb_cp0_reg_data(mem2cp0_cp0_reg_data),  // 写回阶段要写入的寄存器的值（前推）
		.cp0_reg_we_o(ex_cp0_reg_we),  //向下一流水级传递写CP0中的寄存器信号
		.cp0_reg_write_addr_o(ex_cp0_reg_write_addr),
		.cp0_reg_data_o(ex_cp0_reg_data),  // 执行阶段要向cp0传输的数据
		// 直接与cp0相连的两个端口
		.cp0_reg_data_i(cp02ex_data),  //读取的CP0寄存器的值
		.cp0_reg_read_addr_o(ex2cp0_cp0_reg_read_addr),  // 所读取的cp0寄存器的地址， 

		.pcFalse_o(ex_pcFalse),


		//div
		.div_result_i(div_result_i),
		.div_ready_i(div_ready_i),
		.stallreq(stallreq_from_ex_i),
		.div_opdata1_o(div_opdata1_i),
		.div_opdata2_o(div_opdata2_i),
		.div_start_o(div_start_i),
		.signed_div_o(signed_div_i),

	  	//EX模块的输出到EX/MEM模块信息
		.wd_o(ex_wd_o),
		.wreg_o(ex_wreg_o),
		.wdata_o(ex_wdata_o)
		
	);

  //EX/MEM模块
  ex_mem ex_mem0(
		.clk(clk),
		.rst(resetn),
		.ex2mem_pc_i(ex_pc),
		.ex2mem_pc_o(ex2mem_pc),

	  
		//来自执行阶段EX模块的信息	
		.ex_wd(ex_wd_o),
		.ex_wreg(ex_wreg_o),
		.ex_wdata(ex_wdata_o),

		// 特权内陷增加的模块
		.flush(flush),
		.ex_excepttype(ex_excepttype),
		.ex_is_in_delayslot(ex_is_in_delayslot),
		.mem_excepttype(ex2mem_excepttype),
  		.mem_is_in_delayslot(ex2mem_is_in_delayslot),
		.ex_pcFalse(ex_pcFalse),
		.mem_pcFalse(ex2mem_pcFalse),

		.stall(stall),

		//为实现加载、访存指令而添加
 		.ex_aluop(ex2id_mem_aluop),
		.ex_mem_addr(ex2mem_addr),
		.ex_reg2(ex2mem_reg2),
		.mem_aluop(mem_aluop),
		.mem_mem_addr(mem_mem_addr),
		.mem_reg2(mem_reg2),
	
		// Hilo寄存器添加的接口
		.ex_whilo(ex_whilo_o),
		.ex_hi(ex_hi_o),
		.ex_lo(ex_lo_o),
		.mem_whilo(mem_whilo_i),
		.mem_hi(mem_hi_i),
		.mem_lo(mem_lo_i),

		// mfc0,mtc0
		.ex_cp0_reg_we(ex_cp0_reg_we),
		.ex_cp0_reg_write_addr(ex_cp0_reg_write_addr),
		.ex_cp0_reg_data(ex_cp0_reg_data),	// 要向cp0写的数据
		.mem_cp0_reg_we(ex2mem_cp0_reg_we),
		.mem_cp0_reg_write_addr(ex2mem_cp0_reg_write_addr),
		.mem_cp0_reg_data(ex2mem_cp0_reg_data),
	

		//送到访存阶段MEM模块的信息
		.mem_wd(mem_wd_i),
		.mem_wreg(mem_wreg_i),
		.mem_wdata(mem_wdata_i)

						       	
	);
	
  //MEM模块例化
	mem mem0(
		.rst(resetn),
		.mem_pc_i(ex2mem_pc),
		.mem_pc_o(mem_pc),
	
		//来自EX/MEM模块的信息	
		.wd_i(mem_wd_i),
		.wreg_i(mem_wreg_i),
		.wdata_i(mem_wdata_i),

		// Hilo寄存器添加的接口
		.whilo_i(mem_whilo_i),
		.hi_i(mem_hi_i),
		.lo_i(mem_lo_i),
		.whilo_o(mem_whilo_o),
		.hi_o(mem_hi_o),
		.lo_o(mem_lo_o),

		// 内陷特权
		.excepttype_i(ex2mem_excepttype),
		.is_in_delayslot_i(ex2mem_is_in_delayslot),

		.wb_cp0_reg_we(mem2cp0_cp0_reg_we),  // 写回阶段对cp0的前推
		.wb_cp0_reg_write_addr(mem2cp0_cp0_reg_write_addr),
		.wb_cp0_reg_data(mem2cp0_cp0_reg_data),
		
		.excepttype_o(mem2cp0_excepttype),
		.cp0_epc_o(mem2ctrl_cp0_epc),
		.is_in_delayslot_o(mem2cp0_is_in_delayslot),
		.pcFalse_i(ex2mem_pcFalse),
		.bad_addr_o(mem2cp0_bad_addr), // badaddr中存的值


		// mfc0, mtc0
		.cp0_reg_we_i(ex2mem_cp0_reg_we),
		.cp0_reg_write_addr_i(ex2mem_cp0_reg_write_addr),
		.cp0_reg_data_i(ex2mem_cp0_reg_data),
		.cp0_reg_we_o(mem_cp0_reg_we),
		.cp0_reg_write_addr_o(mem_cp0_reg_write_addr),
		.cp0_reg_data_o(mem_cp0_reg_data),

		// 内陷特权
		.cp0_status_i(cp02mem_cp0_status),
		.cp0_cause_i(cp02mem_cp0_cause),
		.cp0_epc_i(cp02mem_cp0_epc),
	  
		//送到MEM/WB模块的信息
		.wd_o(mem_wd_o),
		.wreg_o(mem_wreg_o),
		.wdata_o(mem_wdata_o),

		// 数据加载
		.aluop_i(mem_aluop),
		.mem_addr_i(mem_mem_addr),
		.reg2_i(mem_reg2),

		//datamem与mem相连
		// .mem_data_i(ram_data_i),
		// .mem_addr_o(ram_addr_o),
		// .mem_we_o(ram_we_o),
		// .mem_sel_o(ram_sel_o),
		// .mem_data_o(ram_data_o),
		// .mem_ce_o(ram_ce_o)
		.mem_data_i(data_sram_rdata),
		.mem_addr_o(data_sram_addr_temp),
		.mem_we_o(mem2datamem_we),
		.mem_sel_o(data_sram_wen),
		.mem_data_o(data_sram_wdata),
		.mem_ce_o(data_sram_en)
	);

  //MEM/WB模块
	mem_wb mem_wb0(
		.clk(clk),
		.rst(resetn),
		.mem2wb_pc_i(mem_pc),
		.mem2wb_pc_o(mem2wb_pc),

		//来自访存阶段MEM模块的信息	
		.mem_wd(mem_wd_o),
		.mem_wreg(mem_wreg_o),
		.mem_wdata(mem_wdata_o),

		.stall(stall),

		// Hilo寄存器添加的接口
		.mem_whilo(mem_whilo_o),
		.mem_hi(mem_hi_o),
		.mem_lo(mem_lo_o),
		.wb_whilo(hilo_we_i),
		.wb_hi(hi_i),
		.wb_lo(lo_i),

		// 内线特权
		.flush(flush),

		.mem_cp0_reg_we(mem_cp0_reg_we),
		.mem_cp0_reg_write_addr(mem_cp0_reg_write_addr),
		.mem_cp0_reg_data(mem_cp0_reg_data),
		.wb_cp0_reg_write_addr(mem2cp0_cp0_reg_write_addr),
		.wb_cp0_reg_data(mem2cp0_cp0_reg_data),
		.wb_cp0_reg_we(mem2cp0_cp0_reg_we),
		
		//送到回写阶段的信息
		.wb_wd(wb_wd_i),
		.wb_wreg(wb_wreg_i),
		.wb_wdata(wb_wdata_i)
									       	
	);

	// cp0
	cp0_reg cp0_reg0( 

	.clk(clk),
	.rst(resetn),
	
	
	.we_i(mem2cp0_cp0_reg_we),
	.waddr_i(mem2cp0_cp0_reg_write_addr),
	.data_i(mem2cp0_cp0_reg_data),
	.raddr_i(ex2cp0_cp0_reg_read_addr),
	
	
	.excepttype_i(mem2cp0_excepttype),
	.int_i(int),
	// .cp0_pc_i(mem2cp0_pc),
	.cp0_pc_i(mem_pc),
	.is_in_delayslot_i(mem2cp0_is_in_delayslot),

	// badaddr
	.bad_addr_i(mem2cp0_bad_addr),
	// .badvaddr(mem2cp0_bad_addr),
	
	.data_o(cp02ex_data),
	.status_o(cp02mem_cp0_status),
	.cause_o(cp02mem_cp0_cause),
	.epc_o(cp02mem_cp0_epc),
	
	.timer_int_o(timer_int_o)   
	
);

endmodule