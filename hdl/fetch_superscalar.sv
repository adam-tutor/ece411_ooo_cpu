// module ifetch_superscalar_m
// import rv32i_types::*;
// (
//     input logic clk,
//     input logic rst, 

//     input logic [31:0] ext_pc,
//     input logic ext_pc_select,

//     input logic stall,

//     output logic [31:0] imem_addr,
//     input logic imem_resp,
//     input logic [255:0] imem_rdata,

//     output logic [31:0] inst,
//     output logic [31:0] pc_o,
//     output logic valid
// );

// logic [31:0] pc, pc_next;
// logic [31:0] inst_prev;
// logic jump_nh;

// always_comb begin
//     if (stall) begin
//         imem_addr = pc;
//         inst = inst_prev;
//     end else if (ext_pc_select) begin
//         imem_addr = ext_pc;
//         inst = 32'b0;        
//     end else begin
//         if (imem_resp && !jump_nh) begin
//             imem_addr = pc_next;
//             inst = imem_rdata;
//         end else begin
//             imem_addr = pc;
//             inst = 32'b0;
//         end
        
//     end

//     valid = !ext_pc_select  && imem_resp;
//     if (!valid) begin
//         inst = 32'b0;
//     end
// end

// always_ff @(posedge clk) begin

//     if (rst) begin
//         pc <= 32'h60000000;
//         pc_next <= 32'h60000000;
//         pc_o <= 32'h60000000;

//         inst_prev <= 32'b0;
//         jump_nh <= 1'b0;
//     end else begin
        
//         pc_next <= imem_addr + 32'd32;
//         pc <= imem_addr;

//         inst_prev <= imem_rdata;
//         if (stall) begin
//             pc_o <= pc_o;
//         end else begin
//             pc_o <= imem_addr;
//         end
//         jump_nh <= (ext_pc_select && !imem_resp) || (jump_nh && !imem_resp);
//     end
// end

// endmodule : ifetch_superscalar_m