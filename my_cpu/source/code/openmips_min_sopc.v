`include "defines.v"

module openmips_min_sopc(

	input	wire										clk,
	input wire										rst
	
);

  //连接指令存储器
  wire[`InstAddrBus] inst_addr;
  wire[`InstBus] inst;
  wire rom_ce;
 

 openmips openmips0(  // 这里并没有按照顺序实例化
		.clk(clk),
		.rst(rst),
	
		.rom_addr_o(inst_addr),
		.rom_data_i(inst),
		.rom_ce_o(rom_ce)
	
	);

	// 参考书中的手写存储器
	// inst_rom inst_rom0(
	// 	.addr(inst_addr),
	// 	.inst(inst),
	// 	.ce(rom_ce)	
	// );


    // 这里再生成ip核时一定要勾选generate 32bits interface 否则读出来的指令是间隔为4的
    inst_mem inst_mem0 (
        .clka(clk),    // input wire clka
        .ena(rom_ce),      // input wire ena
        // .wea(wea),      // input wire [3 : 0] wea
        .addra(inst_addr),  // input wire [9 : 0] addra
        // .dina(dina),    // input wire [31 : 0] dina
        .douta(inst)  // output wire [31 : 0] douta
    );


endmodule