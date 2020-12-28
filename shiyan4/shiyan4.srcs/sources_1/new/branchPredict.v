`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/11/16 12:51:08
// Design Name: 
// Module Name: branch_predict
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/*
添加全局历史预测的代码：
需要两个GHR,一个是在预测阶段就进行更新，一个是在MEM阶段进行更新
因为GHR与BHR同用一个PHT，所以GHR的位宽与BHR相同
*/
module branch_predict (
    input wire clk, rst,
    
//    input wire flushD, //zh
    input wire stallD,

    input wire [31:0] pcF,
    input wire [31:0] pcM,
    
    input wire branchM,         // M阶段是否是分支指令
    input wire actual_takeM,    // 实际是否应该跳转
    input wire takeM,           //实际是否跳转
    input wire [31:0] pcMp4,
    input wire [31:0] pcMbranch,


    input wire branchD,        // 译码阶段是否是跳转指令。
//    output wire pred_takeD,      // 预测是否跳转  这条指令要用于PC值的更新


    output wire final_pred,
    output wire flushD, flushE, flushM, //若分支预测错误，MEM阶段结束才会处理结束，所以上面三条指令都是错误的
    output wire actual_add, //若分支预测错误，实际上应该跳转的地址
    output wire controlPC //用于控制pc值的第二个多路选择控制信号，第二个多路选择器主要用于错误的修改
);
    wire pred_takeD_local;
    wire pred_takeD_global;
//局部历史预测
    wire pred_takeF;
    reg pred_takeF_r;
//全局历史预测
    wire pred_takeF_global;
    reg pred_takeF_global_r;
//竞争
    wire pred_choice; //用于选择哪种预测方式
    reg pred_choice_r;
    wire [1:0] cmp; //用于比较局部预测和全局预测哪个预测对了。都预测对为11，局部对全局错10，局部错全局对01,都错为00
    
    

// 定义参数
    parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
    parameter Strongly_local = 2'b00, Weakly_local = 2'b01, Weakly_global = 2'b11, Strongly_global = 2'b10;
    parameter PHT_DEPTH = 6;
    parameter BHT_DEPTH = 10;

    reg [5:0] BHT [(1<<BHT_DEPTH)-1 : 0];
    reg [1:0] PHT [(1<<PHT_DEPTH)-1:0];
//添加全局分支预测所需要的寄存器GHR
    reg [5:0] GHR;
//添加竞争分支预测所需要的CPHT
    reg [1:0] CPHT [(1<<PHT_DEPTH)-1:0];
    
    integer i,j;
    wire [(PHT_DEPTH-1):0] PHT_index;
    wire [(BHT_DEPTH-1):0] BHT_index;
    wire [(PHT_DEPTH-1):0] BHR_value;

// ---------------------------------------预测逻辑---------------------------------------

    assign BHT_index = pcF[11:2];     
    assign BHR_value = BHT[BHT_index];  
    assign PHT_index = BHR_value;
    assign pred_takeF = PHT[PHT_index][1];      // 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。
    
    
//    assign val = pcF[7:2];
    assign PHT_index_global = GHR ^ pcF[7:2]; //将GHR的值与PC的部分地址进行异或作为索引PHT的地址
    assign pred_takeF_global = PHT[PHT_index_global][1];
    
    assign pred_choice = CPHT[PHT_index_global][1]; //选择CPHT的索引是和全局历史预测时的索引相同的 若为1则执行全局预测，否则执行局部预测

        // --------------------------pipeline------------------------------
            always @(posedge clk) begin
                if(rst | flushD) begin
                    pred_takeF_r <= 0;
                    pred_takeF_global_r <= 0;
                    pred_choice_r <= 0;
                end
                else if(~stallD) begin
                    pred_takeF_r <= pred_takeF;
                    pred_takeF_global_r <= pred_takeF_global;
                    pred_choice_r <= pred_choice;
                end
            end
            
        // --------------------------pipeline------------------------------
        
    // 译码阶段输出最终的预测结果
        assign pred_takeD_local = branchD & pred_takeF_r;  
        assign pred_takeD_global = branchD & pred_takeF_global_r;
        assign final_pred = (pred_choice_r == 1) ? pred_takeD_global : pred_takeD_local;
        
        
        //为了将IF阶段全局和局部的预测结果传递到MEM的流水线寄存器上，要通过ID,EXE阶段的流水线寄存器传递
        //就有了下面这些繁琐的代码。。
        reg pred_local_ID_r;
        reg pred_global_ID_r;
        always @(posedge clk) begin
            if(rst) begin
                pred_local_ID_r <= 0;
                pred_global_ID_r <= 0;
            end
            else begin
                pred_local_ID_r <= pred_takeD_local;
                pred_global_ID_r <= pred_takeD_global;
            end
        end
        wire pred_local_ID;
        wire pred_global_ID;
        assign pred_local_ID = pred_local_ID_r;
        assign pred_global_ID = pred_global_ID_r;        
        reg pred_local_EXE_r;
        reg pred_global_EXE_r;
        always @(posedge clk) begin
            if(rst) begin
                pred_local_EXE_r <= 0;
                pred_global_EXE_r <= 0;
            end
            else begin
                pred_local_EXE_r <= pred_local_ID;
                pred_global_EXE_r <= pred_global_ID;
            end
        end
        wire pred_local_EXE;
        wire pred_global_EXE;
        assign pred_local_EXE = pred_local_EXE_r;
        assign pred_global_EXE = pred_global_EXE_r;   
        reg pred_local_MEM_r;
        reg pred_global_MEM_r;   
        always @(posedge clk) begin
            if(rst) begin
                pred_local_MEM_r <= 0;
                pred_global_MEM_r <= 0;
            end
            else begin
                pred_local_MEM_r <= pred_local_EXE_r;
                pred_global_MEM_r <= pred_global_EXE_r;
            end
        end 
        assign cmp = {pred_local_MEM_r == actual_takeM, pred_global_MEM_r == actual_takeM};

        
// ---------------------------------------预测逻辑---------------------------------------


// ---------------------------------------BHT初始化以及更新---------------------------------------
    wire [(PHT_DEPTH-1):0] update_PHT_index;
    wire [(BHT_DEPTH-1):0] update_BHT_index;
    wire [(PHT_DEPTH-1):0] update_BHR_value;
    wire [(PHT_DEPTH-1):0] global_cpht_index;
    wire [(PHT_DEPTH-1):0] update_PHT_global_index;

    assign update_BHT_index = pcM[11:2];     
    assign update_BHR_value = BHT[update_BHT_index];  
    assign update_PHT_index = update_BHR_value;
    assign update_PHT_global_index = pcM[7:2] ^ GHR;
    assign global_cpht_index = pcM[7:2] ^ GHR;

    always@(posedge clk) begin
        if(rst) begin
            for(j = 0; j < (1<<BHT_DEPTH); j=j+1) begin
                BHT[j] <= 0;
            end
        end
        else if(branchM) begin //只有是分支指令才会在MEM阶段更新BHR,该指令的BHR左移，同时根据actual_takeM的结果写入BHR
//            assign new_BHR_value = update_BHR_value << 1 | actual_takeM;
//            BHT[update_BHT_index] <= new_BHR_value;
              BHT[update_BHT_index] <= update_BHR_value << 1 | actual_takeM;
        end
    end
// ---------------------------------------BHT初始化以及更新---------------------------------------


// ---------------------------------------PHT初始化以及更新---------------------------------------
//PHT更新要考虑是用ghr的值还是bhr的值更新对应的pht，所以要将ID阶段选择哪种的哪种预测模式通过流水线寄存器传递到MEM阶段
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
                PHT[i] <= Weakly_taken;
            end
        end
        else if(branchM) begin //这里源代码没有判断是否是branchM，自行添加,也就是说该指令是分支指令时，才对PHT中的对应内容更新
                case(PHT[update_PHT_global_index])
                    2'b00: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b01;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b00;
                        end
                    end
                    2'b01: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b11;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b00;
                        end
                    end
                    2'b10: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b11;
                        end
                    end
                    2'b11: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b01;
                        end                
                    end
                endcase 
                
                case(PHT[update_PHT_index])
                    2'b00: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b01;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b00;
                        end
                    end
                    2'b01: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b11;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b00;
                        end
                    end
                    2'b10: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b11;
                        end
                    end
                    2'b11: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b01;
                        end                
                    end
                endcase 
        end
    end
// ---------------------------------------PHT初始化以及更新---------------------------------------

// ---------------------------------------CPHT初始化以及更新---------------------------------------
//CPHT的更新要知道在ID阶段global和local两种预测的结果，要通过寄存器传递到MEM阶段
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
                CPHT[i] <= Weakly_taken;
            end
        end
        else if(branchM) begin
            case(CPHT[global_cpht_index])
                //状态机4种状态的转换
                2'b00: begin
                    if(cmp == 2'b01) begin
                        CPHT[global_cpht_index] <= 2'b01;
                    end
                end
                2'b01: begin
                    if(cmp == 2'b01) begin
                        CPHT[global_cpht_index] <= 2'b11;
                    end
                    else if(cmp == 2'b10) begin
                        CPHT[global_cpht_index] <= 2'b00;
                    end
                end
                2'b10: begin
                    if(cmp == 2'b10) begin
                         CPHT[global_cpht_index] <= 2'b11;
                    end                   
                end
                2'b11: begin
                    if(cmp == 2'b01) begin
                        CPHT[global_cpht_index] <= 2'b10;
                    end
                    else if(cmp == 2'b10) begin
                        CPHT[global_cpht_index] <= 2'b01;
                    end               
                end
            endcase 
        end
    end
// ---------------------------------------CPHT初始化以及更新---------------------------------------


// ---------------------------------------GHR初始化以及更新---------------------------------------
//全局历史预测在本实验中，是要等到ID阶段判断是否为分支指令后才决定下条指令的地址，而且五级流水线处理器同超标量处理器相比，
//执行阶段同取址阶段相比间隔周期不大，所以为了简化实现在执行阶段进行更新GHR，即在MEM开始的时钟上边沿
    always@(posedge clk) begin
        if(rst) begin
            GHR <= 0;
        end
        else if(branchM) begin // GHR是在IF阶段更新，实际上是在IF结束ID开始的时钟上边沿更新
            GHR  <= GHR << 1 | actual_takeM;
        end
    end  
// ---------------------------------------GHR初始化以及更新---------------------------------------


// ---------------------------------------跳转错误处理---------------------------------------
//总共需要将5个值自ID阶段经过EXE流水线寄存器和MEM流水线寄存器传递过来，这五个值为takeM,actual_takeM,pc+4,pc+4+branch,branchD
//将takeM与actual_takeM比较，若不同则发生错误，需要更新正确的PC值，同时将错误的执行阶段flush掉
//需要改原实验4的流水线寄存器，因为之前的有些流水线寄存器不带flush信号
//takeM是ID阶段分支预测的结果 actual_takeM是ID阶段实际分支判断的结果
    assign flushD = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign flushE = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign flushM = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign controlPC = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign actual_add = (actual_takeM == 1) ? pcMbranch : pcMp4;
// ---------------------------------------跳转错误处理---------------------------------------


endmodule
