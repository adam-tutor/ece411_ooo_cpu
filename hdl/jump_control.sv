module jump_ctrl_m 
import rv32i_types::*;
(
    input logic is_jump,
    input branch_tag_t jump_tag,
    
    output logic flush,
    output branch_tag_t flush_tag
);

assign flush = is_jump;
assign flush_tag = jump_tag;

endmodule