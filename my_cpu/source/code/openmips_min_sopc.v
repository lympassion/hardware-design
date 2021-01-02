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
		.rom_ce_o(rom_ce),

		// data memory
		.ram_we_o(mem_we_i),
		.ram_addr_o(mem_addr_i),
		.ram_sel_o(mem_sel_i),
		.ram_data_o(mem_data_i),
		.ram_data_i(mem_data_o),
		.ram_ce_o(mem_ce_i)	
	
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

	data_memory data_memory0 (
		.clka(clk),            // input wire clka
		// .rsta(rsta),            // input wire rsta
		.ena(ena),              // input wire ena
		.wea(mem_we_i),              // input wire [3 : 0] wea
		.addra(mem_addr_i),          // input wire [31 : 0] addra
		.dina(mem_data_i),            // input wire [31 : 0] dina
		.douta(mem_data_o)        // output wire [31 : 0] douta
		// .rsta_busy(rsta_busy)  // output wire rsta_busy
	);

	// data_ram data_ram0(
	// 	.clk(clk),
	// 	.we(mem_we_i),
	// 	.addr(mem_addr_i),
	// 	.sel(mem_sel_i),
	// 	.data_i(mem_data_i),
	// 	.data_o(mem_data_o),
	// 	.ce(mem_ce_i)		
	// );

endmodule