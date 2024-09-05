module cmp
import rv32i_types::*;
#(
parameter ROB_WIDTH = 64
)
(
    input logic clk,
    input logic rst,
    input logic flush,
 
    input logic issue_in, //ready
    input logic   cmp_type_in,    //Jump or Branch
    input logic [2:0] cmp_op_in,
    input logic [31:0] imm_val_in,
    input logic [31:0] pc_val_in,
    input branch_tag_t br_tag_in,
    input logic [ROB_WIDTH-1:0] dest_ROB_in,
    input logic [31:0] a_in, b_in, //operands
    input logic result_taken,

    output logic busy,
    output logic [31:0] cmp_result,
    output logic [31:0] pc_addr,
    output logic branch_taken,
    output logic cmp_valid,
    output branch_tag_t br_tag_out,
    output logic [ROB_WIDTH-1:0] dest_ROB_out_CMP
);

    logic [31:0] a, b;
    logic issue;

    /* Indicate when CMP is waiting for CDB to take its result.*/ 
    logic waiting_commit, branch_taken_reg; 
    logic [2:0] cmp_op_reg;
    logic [31:0] cmp_result_reg, pc_addr_reg, imm_reg;
    logic [ROB_WIDTH-1:0] ROB_idx_reg;
    branch_tag_t br_tag_reg;
    logic flush_NH, cmp_type_reg;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_ff @( posedge clk ) begin
        if (rst || flush) begin
            cmp_result_reg <= 32'b0;
            pc_addr_reg <= 32'b0;
            branch_taken_reg <= 1'b0;
            waiting_commit <= 1'b0;
            br_tag_reg <= '0;
            ROB_idx_reg <= 'x;
            imm_reg <= '0;
            cmp_type_reg <= '0;
            cmp_op_reg <= '0;
            a <= 32'b0;
            b <= 32'b0;
            issue <= 1'b0;
        end else begin
            cmp_result_reg <= cmp_result;
            if (issue_in) begin
                pc_addr_reg <= pc_val_in;
                cmp_op_reg <= cmp_op_in;
                imm_reg <= imm_val_in;
                waiting_commit <= busy || (issue && !result_taken); 
                br_tag_reg <= br_tag_in;
                cmp_type_reg <= cmp_type_in;
                issue <= 1'b1;
            end else begin
                issue <= issue && !result_taken;
            end 
            branch_taken_reg <= branch_taken;
            ROB_idx_reg <= dest_ROB_in;
            a <= a_in;
            b <= b_in;
        end 
    end

    always_comb begin
        busy = (waiting_commit || issue) && !result_taken;
        cmp_result = '0;
        branch_taken = '0;
        cmp_valid = 1'b0;
        dest_ROB_out_CMP = dest_ROB_in;
        br_tag_out = br_tag_reg;

        if(issue && (cmp_type_reg == 1'b1)) begin
            unique case (cmp_op_reg)
                beq:  branch_taken = (au == bu);
                bne:  branch_taken = (au != bu);
                blt:  branch_taken = (as <  bs);
                bge:  branch_taken = (as >=  bs);
                bltu: branch_taken = (au <  bu);
                bgeu: branch_taken = (au >=  bu);
                default: branch_taken = 1'bx;
            endcase
            cmp_result = '0;
            pc_addr = pc_addr_reg + imm_reg;
            cmp_valid = 1'b1;
            dest_ROB_out_CMP = dest_ROB_in; //ROB index

        end else if(issue && (cmp_type_reg == 1'b0)) begin
            branch_taken = 1'b1;
            cmp_result = pc_addr_reg + imm_reg;
            pc_addr = a + b;
            cmp_valid = 1'b1;
            dest_ROB_out_CMP = dest_ROB_in; //ROB index
        end else if (waiting_commit) begin 
            branch_taken = branch_taken_reg;
            cmp_result = cmp_result_reg;
            pc_addr = pc_addr_reg;
            cmp_valid = 1'b1;
            dest_ROB_out_CMP = ROB_idx_reg;
        end else begin
            branch_taken = '0;
            cmp_result = '0;
            pc_addr = '0;
            cmp_valid = 1'b0;
            dest_ROB_out_CMP = '0;
        end
    end

endmodule : cmp
