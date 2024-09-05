module ResStation_m
import rv32i_types::*; 
#(
    parameter size = 4,
    parameter ROB_WIDTH = 3
)
(
    input logic clk,
    input logic rst,
    input   logic                   flush,
    input branch_tag_t br_tag,
    
    input ResStation_i entries_interface,
    output logic rs_ready,

    input CDB_output_t CDB_value,

    input  logic FU_running,
    input  logic commit_taken,
    output logic issue,
    output logic [31:0] operand1,
    output logic [31:0] operand2,
    output branch_tag_t br_tag_out,
    output logic [ROB_WIDTH-1:0] dest_ROB_out,
    output logic [2:0]  alu_op_out,
    output logic [1:0]  rd_type_out
);

logic entry_empty [size];
logic write_entry [size];

    generate for (genvar i = 0; i < size; i++) begin: entries_alu
        ResEntry_m #(.ROB_WIDTH(ROB_WIDTH)) entires( 
            .clk(clk),
            .rst(rst),
            .flush(flush),
            .read_en(write_entry[i]),
            .rs1_ready(entries_interface.content.rs1_ready),
            .rs1_data(entries_interface.content.rs1_data),
            .rs2_ready(entries_interface.content.rs2_ready),
            .rs2_data(entries_interface.content.rs2_data),
            .br_tag(entries_interface.content.br_tag),
            .dest_ROB_in(entries_interface.content.dest_ROB_in),
            .alu_opcode(entries_interface.content.alu_opcode),
            .alu_rd_type(entries_interface.content.alu_rd_type),
            .empty(entry_empty[i]),
            .CDB_value(CDB_value),
            .running(FU_running),
            .commit_taken(commit_taken),
            .issue(issue),
            .operand1(operand1),
            .operand2(operand2),
            .br_tag_out(br_tag_out),
            .dest_ROB_out(dest_ROB_out),
            .alu_op_out(alu_op_out),
            .rd_type_out(rd_type_out),
            .flush_tag(br_tag)
        );
    end endgenerate

    always_comb begin 
        rs_ready = 1'b0;
        write_entry = '{default:0};
        
        for (int idx = 0; idx < size; idx++) begin
            if (entry_empty[idx]) begin
                rs_ready = 1'b1;
                break;
            end 
        end
        if (entries_interface.read_dispatch) begin 
            for (int idx = 0; idx < size; idx++) begin
                if (entry_empty [idx]) begin
                    write_entry[idx] = 1'b1;
                    break;
                end
            end
        end
    end

endmodule : ResStation_m


/* rs1_ready: 1 if rs1 data can be used immediately
 * rs1_data: rs1 value if ready, otherwise it stores dependent ROB # in [ROB_WIDTH:0] 
 * CDB_value: input from CDB
 */ 
module ResEntry_m
import rv32i_types::*; 
#(
    parameter ROB_WIDTH = 3
)
(
    input logic clk,
    input logic rst,
    input logic flush, 
    input branch_tag_t flush_tag,

    // Input interface from dispatch stage 
    input logic read_en,
    input logic rs1_ready,
    input logic [31:0] rs1_data,
    input logic rs2_ready,
    input logic [31:0] rs2_data,
    input branch_tag_t br_tag,
    input logic [ROB_WIDTH-1:0] dest_ROB_in,
    input logic [2:0] alu_opcode,
    input logic [1:0] alu_rd_type,

    input  logic commit_taken,

    input CDB_output_t CDB_value,

    // Output interface for dispatch stage to select content_reg
    output logic empty,

    // Output interface to Functional Unit
    input logic running,
    output logic issue,
    output logic [31:0] operand1,
    output logic [31:0] operand2,
    output branch_tag_t br_tag_out,
    output logic [ROB_WIDTH-1:0] dest_ROB_out,
    output logic [2:0]  alu_op_out,
    output logic [1:0]  rd_type_out
);

logic content_reg_valid;
ResEntry_reg_t content_reg, content_reg_next;
logic rs1_valid, rs2_valid;

always_ff @(posedge clk) begin
    if (rst) begin
        content_reg <= '0;
        content_reg_valid <= 1'b0;
    end else begin
        if (flush) begin
            if (br_tag_out.sign == flush_tag.sign) begin
                if ((br_tag_out.tag & flush_tag.tag) == flush_tag.tag) begin
                    content_reg_valid <= 1'b0;
                end
            end else if (br_tag_out.sign != flush_tag.sign) begin
                if ((br_tag_out.tag & flush_tag.tag) == br_tag_out.tag) begin
                    content_reg_valid <= 1'b0;
                end 
            end else begin
                content_reg <= content_reg_next;
            end 
        end else if (read_en) begin
            content_reg <= {rs1_ready, rs1_data, rs2_ready, rs2_data, br_tag, dest_ROB_in, alu_opcode, alu_rd_type};
            content_reg_valid <= 1'b1;
        end else begin 
            content_reg <= content_reg_next;
            content_reg_valid <= content_reg_valid && !issue;
        end
    end
end

assign dest_ROB_out = content_reg.dest_ROB_in;
assign alu_op_out = content_reg.alu_opcode;
assign rd_type_out = content_reg.alu_rd_type;
assign br_tag_out = content_reg.br_tag;

always_comb begin
    operand1 = 32'bx;
    operand2 = 32'bx;
    content_reg_next = content_reg;
    rs1_valid = 1'b0;
    rs2_valid = 1'b0;

    if (content_reg.rs1_ready) begin
        operand1 = content_reg.rs1_data;
        rs1_valid = 1'b1;
    end else if ((CDB_value.dest_ROB == content_reg.rs1_data[ROB_WIDTH-1:0]) && CDB_value.commit_valid) begin
        operand1 = CDB_value.rd_v;
        rs1_valid = 1'b1;
        content_reg_next.rs1_ready = 1'b1;
        content_reg_next.rs1_data = operand1;
    end
    if (content_reg.rs2_ready) begin
        operand2 = content_reg.rs2_data;
        rs2_valid = 1'b1;
    end else if ((CDB_value.dest_ROB == content_reg.rs2_data[ROB_WIDTH-1:0]) && CDB_value.commit_valid) begin
        operand2 = CDB_value.rd_v;
        rs2_valid = 1'b1;
        content_reg_next.rs2_ready = 1'b1;
        content_reg_next.rs2_data = operand2;
    end

    issue = rs1_valid && rs2_valid && content_reg_valid && !running;
    empty = !content_reg_valid || (issue && commit_taken);

end
    
endmodule : ResEntry_m

