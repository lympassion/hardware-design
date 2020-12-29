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
`define NotInDelaySlot 1'b0
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


//指令
`define EXE_ORI  6'b001101


`define EXE_NOP 6'b000000


//AluOp
`define EXE_OR_OP    8'b00100101
`define EXE_ORI_OP  8'b01011010


`define EXE_NOP_OP    8'b00000000

//AluSel
`define EXE_RES_LOGIC 3'b001

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
