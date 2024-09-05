module dispatch_m
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           flush,

    input   logic           stall,
    input   logic           rob_full,

    input decoded_inst_t decode_in,  
    input rvfi_signal_t  rvfi_in,

    output  logic           rob_enqueue,
    output  ROBentry_t      rob_enqueue_wdata,
    input   logic [rob_idx_bits - 1: 0] rob_idx,
    output  logic [rob_idx_bits-1:0]    rs1_rob_idx,
    output  logic [rob_idx_bits-1:0]    rs2_rob_idx,
    input   ROBinfo_t       rs1_ROB_info,
    input   ROBinfo_t       rs2_ROB_info,

    //Reg File Input signals
    input   RegFile_t       rs1_v, rs2_v,
    output  logic   [4:0]   rs1_s, rs2_s,
    output  logic   [4:0]   rd_dis,
    output  logic           regf_rob_we,
    output  ROBinfo_t       rob_info,
    output  op_type   function_type,
    output  logic           branch_dispatched,

    input   CDB_output_t    CDB_value,

    //RS Station Input
    input   logic           rs_ready_alu,
    output  ResStation_i    entries_interface_alu,
    input   logic           rs_ready_mul,
    output  ResStationMult_i    entries_interface_mul,
    input   logic           rs_ready_div,
    output  ResStationDiv_i     entries_interface_div,
    input   logic           rs_ready_cmp,
    output  ResStationCmp_i    entries_interface_cmp, 
    input   logic           rs_ready_ld,  
    output  logic           ld_dispatch,
    output  ResEntryLd_reg_t entries_interface_ld,   

    input   logic           rs_ready_st,
    output  logic           st_dispatch, 
    output  ResEntrySt_reg_t entries_interface_st,
    
    input   logic           st_committed 
);

decoded_inst_t decode;
rvfi_signal_t  rvfi;

ResEntry_base_t RS_base;
logic alu_dispatch, mul_dispatch, cmp_dispatch, div_dispatch;
logic cmp_type;


/* keeps track of how many store must be committed before current load inst
   (How many stores are currently in RS) */
logic [st_qsize-1:0] load_offset;
logic [st_qsize-1:0] load_offset_comb;
branch_tag_t br_tag;
logic [st_qsize-1:0] post_branch_st_count;

assign function_type = decode.function_type;
assign cmp_type = (decode.function_type == brn_op);
assign entries_interface_alu = {alu_dispatch, RS_base, decode.alu_opcode, decode.alu_rd_type};
assign entries_interface_mul = {mul_dispatch, RS_base, decode.mult_type, decode.upper};
assign entries_interface_div = {div_dispatch, RS_base, decode.div_op};
assign entries_interface_cmp = {cmp_dispatch, RS_base, cmp_type, decode.alu_opcode, decode.imm_val, decode.current_pc};
assign entries_interface_ld = {load_offset_comb, RS_base.rs1_ready, RS_base.rs1_data, RS_base.br_tag, RS_base.dest_ROB, decode.imm_val, decode.funct3};
assign entries_interface_st = {RS_base, decode.imm_val, decode.funct3};


always_ff @(posedge clk) begin
    if (rst) begin
        decode <= 'x;
        rvfi <= 'x;
        load_offset <= '0;
        br_tag <= '0;
        post_branch_st_count <= '0;
    end else if (flush) begin
        decode <= 'x;
        rvfi <= 'x;
        if (st_committed) begin
            load_offset <= load_offset >> (post_branch_st_count + 1);
        end else begin
            load_offset <= load_offset >> post_branch_st_count;
        end
    end else if (stall) begin
        decode <= decode;
        rvfi <= rvfi;

        if (st_committed) begin
            load_offset <= (load_offset >> 1);
        end
    end else begin
        decode <= decode_in;
        rvfi <= rvfi_in;

        if (st_committed && st_dispatch && rvfi.valid) begin
            /* Don't change load_offset */
        end else if (st_committed) begin
            load_offset <= (load_offset >> 1);
        end else if (st_dispatch && rvfi.valid) begin
            load_offset <= (load_offset << 1) | st_qsize'(1);
        end
    end

    

    if ((decode_in.function_type == brn_op || decode_in.function_type == jmp_op) && (!rob_full && rvfi_in.valid && !stall) || flush && !rst) begin
        br_tag.tag <= br_tag.tag[7] ? 8'b0 : (br_tag.tag << 1'b1) | 8'b1;
        br_tag.sign <= br_tag.tag[7] + br_tag.sign;
    end 

    if (cmp_dispatch && rvfi.valid && !stall && !rst) begin
        post_branch_st_count <= '0;
    end else if (st_dispatch && rvfi.valid && !rst) begin
        post_branch_st_count <= post_branch_st_count + st_qsize'(1);
    end


end

always_comb begin
    alu_dispatch = 1'b0;
    mul_dispatch = 1'b0;
    cmp_dispatch = 1'b0;
    div_dispatch = 1'b0;
    ld_dispatch = 1'b0;
    st_dispatch = 1'b0;

    rs1_s = rvfi.rs1_addr;
    rs2_s = rvfi.rs2_addr;
    rs1_rob_idx = rs1_v.ROB_idx;
    rs2_rob_idx = rs2_v.ROB_idx;

    rob_enqueue_wdata = '0;

    RS_base = 'x;

    branch_dispatched = 1'b0;

    rob_enqueue = 1'b0;
    rob_info = 'x;
    regf_rob_we = 1'b0;
    rd_dis = 5'b0;


    if (st_committed) begin
        load_offset_comb = load_offset >> 1;
    end else begin
        load_offset_comb = load_offset;
    end 

    if(!rob_full && rvfi.valid && !stall) begin
        //Rob Info
        rob_enqueue = 1'b1;
        rob_enqueue_wdata.dest_reg = rvfi.rd_addr;
        rob_enqueue_wdata.comp_val = 'x;
        rob_enqueue_wdata.RVFI = rvfi;
        rob_enqueue_wdata.is_store = (decode.mem_op == 2'b01);
        rob_enqueue_wdata.is_load = (decode.mem_op == 2'b10);
        rob_enqueue_wdata.ready = rob_enqueue_wdata.is_store;
        rob_enqueue_wdata.br_tag = br_tag;
        //Register Info
        regf_rob_we = 1'b1;
        rd_dis = rvfi.rd_addr;
        rob_info.ROB_busy = 1'b1;
        rob_info.ROB_idx = rob_idx;
        rob_info.value = 32'bx;
        rob_info.br_tag = br_tag;
        

        mul_dispatch = (decode.function_type == mul_op) && rs_ready_mul;
        div_dispatch = (decode.function_type == div_op) && rs_ready_div;
        alu_dispatch = (decode.function_type == alu_op) && rs_ready_alu;
        st_dispatch = decode.mem_op == 2'b01 && rs_ready_st;
        ld_dispatch = decode.mem_op == 2'b10 && rs_ready_ld;
        if(((decode.function_type == brn_op) || (decode.function_type == jmp_op)) && rs_ready_cmp) begin
            cmp_dispatch = 1'b1;
            rob_enqueue_wdata.is_branch = 1'b1;
        end
        
        branch_dispatched = cmp_dispatch;


        /* operand is ready when: a) value is immediate b) value ready in register c) value is not in reg 
                                but in ROB, or d) value is not in ROB but waiting in CDB */
        RS_base.rs1_ready = decode.data_a_is_imm || !rs1_v.ROB_busy || (rs1_v.ROB_busy && !rs1_ROB_info.ROB_busy) || (rs1_v.ROB_busy && CDB_value.dest_ROB == rs1_v.ROB_idx && CDB_value.commit_valid);
        RS_base.rs2_ready = decode.data_b_is_imm || !rs2_v.ROB_busy || (rs2_v.ROB_busy && !rs2_ROB_info.ROB_busy) || (rs2_v.ROB_busy && CDB_value.dest_ROB == rs2_v.ROB_idx && CDB_value.commit_valid);
        RS_base.dest_ROB = rob_idx;
        RS_base.br_tag = br_tag;

        /* Set operand 1 from different source */
        if (decode.data_a_is_imm) begin
            RS_base.rs1_data = decode.operand_a;
        end else begin
            /* Data valid in register */
            if (!rs1_v.ROB_busy) begin
                RS_base.rs1_data = rs1_v.reg_value;

            /* Data valid in ROB */
            end else if ((rs1_v.ROB_busy && !rs1_ROB_info.ROB_busy)) begin
                RS_base.rs1_data = rs1_ROB_info.value;
            
            /* Data valid in CDB*/
            end else if (rs1_v.ROB_busy && CDB_value.dest_ROB == rs1_v.ROB_idx && CDB_value.commit_valid) begin
                RS_base.rs1_data = CDB_value.rd_v;
            end else begin
                RS_base.rs1_data = 32'(rs1_v.ROB_idx);
            end 
        end


        if (decode.data_b_is_imm) begin
            RS_base.rs2_data = decode.operand_b;
        end else begin
            if (!rs2_v.ROB_busy) begin
                RS_base.rs2_data = rs2_v.reg_value;
            end else if (rs2_v.ROB_busy && !rs2_ROB_info.ROB_busy) begin
                RS_base.rs2_data = rs2_ROB_info.value;
            end else if (rs2_v.ROB_busy && CDB_value.dest_ROB == rs2_v.ROB_idx && CDB_value.commit_valid) begin
                RS_base.rs2_data = CDB_value.rd_v;
            end else begin
                RS_base.rs2_data = 32'(rs2_v.ROB_idx);
            end
        end
    end
end

endmodule : dispatch_m
