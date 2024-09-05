module cdb
import rv32i_types::*;
#(
    parameter ROB_WIDTH = 64
)
(
    //ALU Signals
    input logic [31:0] alu_result,
    input logic alu_valid,
    input logic [ROB_WIDTH-1:0] dest_ROB_in,
    input branch_tag_t alu_br_tag,
    output logic ALU_result_taken,
    
    //Multiply Signals
    input logic [31:0] mul_result, //p from multiplier.sv
    input logic mul_ready,
    input logic [ROB_WIDTH-1:0] dest_ROB_in_mul,
    input branch_tag_t mul_br_tag,
    output logic MUL_result_taken,

    //Divide Signals
    input logic [31:0] div_result, //p from multiplier.sv
    input logic div_ready,
    input logic [ROB_WIDTH-1:0] dest_ROB_in_div,
    input branch_tag_t div_br_tag,
    output logic DIV_result_taken,

    input logic ldst_ready,
    input logic [31:0] ldst_result,
    input logic [ROB_WIDTH-1:0] dest_ROB_in_ldst,
    input branch_tag_t ldst_br_tag,
    input mem_rvfi ld_rvfi,
    output logic ldst_result_taken,

    //Control Signals
    input logic [31:0] cmp_result,
    input logic [31:0] pc_addr,
    input logic branch_taken,
    input branch_tag_t cmp_br_tag,
    input logic cmp_valid,
    input logic [ROB_WIDTH-1:0] dest_ROB_in_cmp,
    output logic CMP_result_taken,

    input logic commit_valid,

    output CDB_output_t CDB_output
);

    always_comb begin
            CDB_output = '0;
            ALU_result_taken = 1'b0;
            ldst_result_taken = 1'b0;
            CMP_result_taken = 1'b0;
            MUL_result_taken = 1'b0;
            DIV_result_taken = 1'b0;

            if(cmp_valid) begin
                CDB_output.commit_ready = 1'b1;
                CDB_output.dest_ROB = dest_ROB_in_cmp;
                CDB_output.rd_v = cmp_result;
                CDB_output.branch_taken = branch_taken;
                CDB_output.br_tag = cmp_br_tag;
                CDB_output.jump_pc = pc_addr;
                CMP_result_taken = 1'b1;
            end else if(mul_ready) begin
                CDB_output.commit_ready = 1'b1;
                CDB_output.dest_ROB = dest_ROB_in_mul;
                CDB_output.rd_v = mul_result;
                CDB_output.br_tag = mul_br_tag;
                MUL_result_taken = 1'b1;
            end else if(div_ready) begin
                CDB_output.commit_ready = 1'b1;
                CDB_output.dest_ROB = dest_ROB_in_div;
                CDB_output.rd_v = div_result;
                CDB_output.br_tag = div_br_tag;
                DIV_result_taken = 1'b1;
            end else if (ldst_ready) begin
                CDB_output.commit_ready = 1'b1;
                CDB_output.dest_ROB = dest_ROB_in_ldst;
                CDB_output.rd_v = ldst_result;
                CDB_output.br_tag = ldst_br_tag;
                CDB_output.ld_rvfi = ld_rvfi;
                ldst_result_taken = 1'b1;
            end 
            else if(alu_valid) begin
                CDB_output.commit_ready = 1'b1;
                CDB_output.dest_ROB = dest_ROB_in;
                CDB_output.rd_v = alu_result;
                CDB_output.br_tag = alu_br_tag;
                ALU_result_taken = 1'b1;
            end
            
        CDB_output.commit_valid = CDB_output.commit_ready && commit_valid;
    end
    //need more else ifs for future functions




endmodule : cdb
