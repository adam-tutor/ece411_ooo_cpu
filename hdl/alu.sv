module alu_unit
import rv32i_types::*;
#(
parameter ROB_WIDTH = 64
)
(
    input logic clk,
    input logic rst,

    input logic [2:0] alu_operation,
    input logic issue_in, //ready
    input logic [1:0] alu_rd_type,
    input branch_tag_t br_tag_in,
    input logic [ROB_WIDTH-1:0] dest_ROB_in,
    input logic [31:0] a_in, b_in, //operands
    input logic result_taken,

    output logic busy,
    output logic [31:0] alu_result,
    output logic alu_valid,
    output branch_tag_t br_tag_out,
    output logic [ROB_WIDTH-1:0] dest_ROB_out_ALU
);

    logic [31:0] a, b;
    logic [2:0] alu_operaion_reg;
    logic [1:0] alu_rd_type_reg;
    logic issue;

    /* Indicate when ALU is waiting for CDB to take its result.*/ 
    logic waiting_commit; 
    logic [31:0] result_reg;
    logic [ROB_WIDTH-1:0] dest_ROB_reg;
    branch_tag_t br_tag_reg;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_ff @( posedge clk ) begin
        if (rst) begin
            result_reg <= 32'b0;
            br_tag_reg <= '0;
            dest_ROB_reg <= '0;
            waiting_commit <= 1'b0;
            a <= 32'b0;
            b <= 32'b0;
            issue <= 1'b0;
        end else begin
            result_reg <= alu_result;
            if (issue_in) begin
                dest_ROB_reg <= dest_ROB_in;
                a <= a_in;
                b <= b_in;
                alu_operaion_reg <= alu_operation;
                alu_rd_type_reg <= alu_rd_type;
                br_tag_reg <= br_tag_in;
            end 
            waiting_commit <= busy || (issue && !result_taken); 
            issue <= issue_in;
            
        end 
    end

    always_comb begin
        busy = (waiting_commit || issue) && !result_taken;
        alu_result = '0;
        alu_valid = 1'b0;
        dest_ROB_out_ALU = dest_ROB_reg;
        br_tag_out = br_tag_reg;

        if(issue && (alu_rd_type_reg == 2'b11)) begin
            unique case (alu_operaion_reg)
                alu_add: alu_result = au + bu;
                alu_sll: alu_result = au <<  bu[4:0];
                alu_sra: alu_result = unsigned'(as >>> bu[4:0]);
                alu_sub: alu_result = au - bu;
                alu_xor: alu_result = au ^ bu;
                alu_srl: alu_result = au >> bu[4:0];
                alu_or:  alu_result = au | bu;
                alu_and: alu_result = au & bu;
                default: alu_result = 'x;
            endcase

            alu_valid = 1'b1;
            dest_ROB_out_ALU = dest_ROB_reg; //ROB index
        end else if(issue && (alu_rd_type_reg == 2'b10)) begin
            unique case (alu_operaion_reg)
                blt: alu_result = {31'b0, (as<bs)};
                bltu: alu_result = {31'b0, (au<bu)};
                default: alu_result = 'x;
            endcase
            alu_valid = 1'b1;
            dest_ROB_out_ALU = dest_ROB_reg; //ROB index
        end else if (waiting_commit) begin 
            alu_result = result_reg;
            alu_valid = 1'b1;
            dest_ROB_out_ALU = dest_ROB_reg;
        end else begin
            alu_valid = 1'b0;
            dest_ROB_out_ALU = '0;
        end
    end

endmodule : alu_unit
