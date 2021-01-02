//全局
`define RstEnable 1'b1
`define RstDisable 1'b0
`define ZeroWord 32'h00000000        // 就是用来表示数值0
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define AluOpBus 7:0                 // 译码阶段输出的aluop_o的宽度
`define AluSelBus 2:0                // 译码阶段输出的alusel_o的宽度
`define InstValid 1'b0
`define InstInvalid 1'b1
`define Stop 1'b1
`define NoStop 1'b0
`define InDelaySlot 1'b1             // 
`define NotInDelaySlot 1'b0          // 不是分支槽指令
`define Branch 1'b1                  // 是否为分支指令
`define NotBranch 1'b0               
`define InterruptAssert 1'b1         // 
`define InterruptNotAssert 1'b0
`define TrapAssert 1'b1              // 
`define TrapNotAssert 1'b0
`define True_v 1'b1
`define False_v 1'b0
`define ChipEnable 1'b1              // 芯片使能
`define ChipDisable 1'b0



// 指令 op位
`define EXE_SPECIAL_INST 6'b000000  // 包括R型逻辑，R移位,数据移位
`define EXE_REGIMM_INST 6'b000001   // branch 
`define EXE_HILO_INST 6'b011100



//指令 功能码
// 8条逻辑指令
`define EXE_AND  6'b100100  
`define EXE_OR   6'b100101
`define EXE_XOR 6'b100110
`define EXE_NOR 6'b100111
`define EXE_ANDI 6'b001100
`define EXE_ORI  6'b001101
`define EXE_XORI 6'b001110
`define EXE_LUI 6'b001111

// 6条移位指令
`define EXE_SLL  6'b000000
`define EXE_SLLV  6'b000100
`define EXE_SRL  6'b000010
`define EXE_SRLV  6'b000110
`define EXE_SRA  6'b000011
`define EXE_SRAV  6'b000111

`define EXE_SYNC  6'b001111
`define EXE_PREF  6'b110011

`define EXE_NOP 6'b000000
`define SSNOP 32'b00000000000000000000000001000000

// 4条数据移动指令Hilo
`define EXE_MFHI  6'b010000
`define EXE_MFLO  6'b010010
`define EXE_MTHI  6'b010001
`define EXE_MTLO  6'b010011
`define EXE_MOVN  6'b001011  //
`define EXE_MOVZ  6'b001010  //

// 14条算术运算指令
`define EXE_ADD    6'b100000  
`define EXE_ADDU   6'b100001
`define EXE_SUB    6'b100010
`define EXE_SUBU   6'b100011
`define EXE_SLT    6'b101010

`define EXE_SLTU   6'b101011
`define EXE_MULT   6'b011000
`define EXE_MULTU  6'b011001
`define EXE_DIV    6'b011010  
`define EXE_DIVU   6'b011011

`define EXE_ADDI   6'b001000
`define EXE_ADDIU   6'b001001
`define EXE_SLTI   6'b001010  //这里的功能吗虽然和movz相同,但是movz属于special指令,在译码的时候会区分开来
`define EXE_SLTIU  6'b001011

`define EXE_DIV  6'b011010
`define EXE_DIVU  6'b011011


// 分支跳转指令
`define EXE_J  6'b000010
`define EXE_JAL  6'b000011
`define EXE_JALR  6'b001001
`define EXE_JR  6'b001000
`define EXE_BEQ  6'b000100
`define EXE_BGEZ  5'b00001
`define EXE_BGEZAL  5'b10001
`define EXE_BGTZ  6'b000111
`define EXE_BLEZ  6'b000110
`define EXE_BLTZ  5'b00000
`define EXE_BLTZAL  5'b10000
`define EXE_BNE  6'b000101


// 数据加载指令
`define EXE_LB  6'b100000
`define EXE_LBU  6'b100100
`define EXE_LH  6'b100001
`define EXE_LHU  6'b100101
`define EXE_LW  6'b100011
`define EXE_SB  6'b101000
`define EXE_SH  6'b101001
`define EXE_SW  6'b101011



//AluOp 对于special，需要知道运算的子类型
// 8条逻辑指令
`define EXE_AND_OP   8'b00100100
`define EXE_OR_OP    8'b00100101
`define EXE_XOR_OP  8'b00100110
`define EXE_NOR_OP  8'b00100111
`define EXE_ANDI_OP  8'b01011001
`define EXE_ORI_OP  8'b01011010
`define EXE_XORI_OP  8'b01011011
`define EXE_LUI_OP  8'b01011100  

// 6条移位指令
`define EXE_SLL_OP  8'b01111100
`define EXE_SLLV_OP  8'b00000100
`define EXE_SRL_OP  8'b00000010
`define EXE_SRLV_OP  8'b00000110
`define EXE_SRA_OP  8'b00000011
`define EXE_SRAV_OP  8'b00000111

`define EXE_NOP_OP    8'b00000000

// 4条数据移动指令Hilo
`define EXE_MFHI_OP  8'b00010000
`define EXE_MTHI_OP  8'b00010001
`define EXE_MFLO_OP  8'b00010010
`define EXE_MTLO_OP  8'b00010011
`define EXE_MOVZ_OP  8'b00001010
`define EXE_MOVN_OP  8'b00001011

// 14条算术运算指令
`define EXE_ADD_OP  8'b00100000
`define EXE_ADDU_OP  8'b00100001
`define EXE_SUB_OP  8'b00100010
`define EXE_SUBU_OP  8'b00100011
`define EXE_SLT_OP  8'b00101010

`define EXE_SLTU_OP  8'b00101011
`define EXE_MULT_OP  8'b00011000
`define EXE_MULTU_OP  8'b00011001
`define EXE_DIV_OP  8'b00011010
`define EXE_DIVU_OP  8'b00011011

`define EXE_ADDI_OP  8'b01010101
`define EXE_ADDIU_OP  8'b01010110
`define EXE_SLTI_OP  8'b01010111
`define EXE_SLTIU_OP  8'b01011000 
// `define EXE_CLZ_OP  8'b10110000
// `define EXE_CLO_OP  8'b10110001
// `define EXE_MUL_OP  8'b10101001


// 分支跳转指令
`define EXE_J_OP  8'b01001111
`define EXE_JAL_OP  8'b01010000
`define EXE_JALR_OP  8'b00001001
`define EXE_JR_OP  8'b00001000
`define EXE_BEQ_OP  8'b01010001
`define EXE_BGEZ_OP  8'b01000001
`define EXE_BGEZAL_OP  8'b01001011
`define EXE_BGTZ_OP  8'b01010100
`define EXE_BLEZ_OP  8'b01010011
`define EXE_BLTZ_OP  8'b01000000
`define EXE_BLTZAL_OP  8'b01001010
`define EXE_BNE_OP  8'b01010010

// 数据加载
`define EXE_LB_OP  8'b11100000
`define EXE_LBU_OP  8'b11100100
`define EXE_LH_OP  8'b11100001
`define EXE_LHU_OP  8'b11100101
`define EXE_LW_OP  8'b11100011
`define EXE_PREF_OP  8'b11110011
`define EXE_SB_OP  8'b11101000
`define EXE_SH_OP  8'b11101001
`define EXE_SW_OP  8'b11101011



//AluSel 对应着现在已经实现的指令类型
`define EXE_RES_LOGIC 3'b001   
`define EXE_RES_SHIFT 3'b010  
// `define EXE_RES_HILO 3'b010  // 这个地方重名
`define EXE_RES_HILO 3'b011
`define EXE_RES_ARITHMETIC 3'b100	
`define EXE_RES_MUL 3'b101
`define EXE_RES_JUMP_BRANCH 3'b110
`define EXE_RES_LOAD_STORE 3'b111	



// `define EXE_RES_ZERO 3'b111 //movn movz两条指令
`define EXE_RES_NOP 3'b000


//指令存储器inst_rom
`define InstAddrBus 31:0          // ROM地址总线的宽度
`define InstBus 31:0              // ROM数据的宽度
`define InstMemNum 131071         // 
`define InstMemNumLog2 17


//通用寄存器regfile
`define RegAddrBus 4:0           // 寄存器堆的地址线宽度
`define RegBus 31:0              // 寄存器堆的数据线宽度
`define RegWidth 32              // 通用寄存器的宽度
`define DoubleRegWidth 64        // 两倍通用寄存器的宽度
`define DoubleRegBus 63:0
`define RegNum 32                // 寄存器堆数量
`define RegNumLog2 5
`define NOPRegAddr 5'b00000

// div模块
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0