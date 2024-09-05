module cpu
import rv32i_types::*;
(
    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    input   logic           clk,
    input   logic           rst,

    // output  logic   [31:0]  imem_addr,
    // output  logic   [3:0]   imem_rmask,
    // input   logic   [31:0]  imem_rdata,
    // input   logic           imem_resp,

    // output  logic   [31:0]  dmem_addr,
    // output  logic   [3:0]   dmem_rmask,
    // output  logic   [3:0]   dmem_wmask,
    // input   logic   [31:0]  dmem_rdata,
    // output  logic   [31:0]  dmem_wdata,
    // input   logic           dmem_resp

    // Single memory port connection when caches are integrated into design (CP3 and after)
    
    output logic   [31:0]      bmem_addr,
    output logic               bmem_read,
    output logic               bmem_write,
    output logic   [63:0]      bmem_wdata,

    input logic               bmem_ready,
    input logic   [31:0]      bmem_raddr,
    input logic   [63:0]      bmem_rdata,
    input logic               bmem_rvalid
    

);
    localparam RS_SIZE = 1;
    localparam ROB_ENTRIES = 8;
    localparam ROB_IDX_WIDTH = $clog2(ROB_ENTRIES);
    localparam NUM_SET_CACHE = 16;


    logic                   flush;

// /*
    //Memory Signals 
    logic   [31:0]  imem_addr, dmem_addr;
    logic   [3:0]   imem_rmask, dmem_rmask;
    logic   [3:0]   imem_wmask, dmem_wmask;
    logic   [31:0]  imem_wdata, dmem_wdata;
    logic   [31:0]  imem_rdata, dmem_rdata;
    logic           imem_resp, dmem_resp;

    logic   [31:0]  ibmem_addr, dbmem_addr;
    logic           ibmem_read, dbmem_read;
    logic           ibmem_write, dbmem_write;
    logic   [255:0] ibmem_wdata, dbmem_wdata;
    logic   [255:0] ibmem_rdata, dbmem_rdata;
    logic           ibmem_resp, dbmem_resp;

    logic   [31:0]  dfp_addr;
    logic           dfp_read;
    logic           dfp_write;
    logic   [255:0] dfp_rdata;
    logic   [255:0] dfp_wdata;
    logic           dfp_resp;

    assign imem_wmask = '0;
    assign imem_wdata = '0;
    
    i_cache #(.NUM_SET(NUM_SET_CACHE), .NUM_WAY(4)) i_memcache(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // cpu side signals, ufp -> upward facing port
        .ufp_addr(imem_addr),
        .ufp_rmask(imem_rmask),
        .ufp_wmask(imem_wmask),
        .ufp_wdata(imem_wdata),
        .ufp_rdata(imem_rdata),
        .ufp_resp(imem_resp),
        // memory side signals, dfp -> downward facing port
        .dfp_addr(ibmem_addr),
        .dfp_read(ibmem_read),
        .dfp_write(ibmem_write),
        .dfp_wdata(ibmem_wdata),
        .dfp_rdata(ibmem_rdata),
        .dfp_resp(ibmem_resp)
    );

    cache #(.NUM_SET(NUM_SET_CACHE), .NUM_WAY(4)) d_memcache(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // cpu side signals, ufp -> upward facing port
        .ufp_addr(dmem_addr),
        .ufp_rmask(dmem_rmask),
        .ufp_wmask(dmem_wmask),
        .ufp_wdata(dmem_wdata),
        .ufp_rdata(dmem_rdata),
        .ufp_resp(dmem_resp),
        // memory side signals, dfp -> downward facing port
        .dfp_addr(dbmem_addr),
        .dfp_read(dbmem_read),
        .dfp_write(dbmem_write),
        .dfp_wdata(dbmem_wdata),
        .dfp_rdata(dbmem_rdata),
        .dfp_resp(dbmem_resp)
    );

    arbiter cache_arbiter(
        .*
    );


    cacheline_adaptor cacheline_adaptor(
        .*
    );

    inst_queue_interface inst_queue_i; 
    decoded_inst_t decoded_inst;
    rvfi_signal_t rvfi;
    rvfi_signal_t rvfi_pipeline;

    // temporary Debug signals
    logic [64:0] enqueue_wdata, dequeue_rdata;
    logic full, empty, dequeue, enqueue, stop;
    logic [31:0] pc, inst;
    logic   [31:0]  temp_rdata;
    logic           temp_resp;
    logic           stall_dec_dis;
    logic [31:0] control_buffer_wdata, control_buffer_rdata;
    logic [31:0] branch_pc_addr_next;
    logic jump_taken;

    logic commit_valid;

    CDB_output_t CDB_values;
    //RS Signals
    ResStation_i entries_interface_alu;
    logic rs_ready_alu;
    
    logic FU_running_alu;
    logic issue_alu;
    logic [31:0] operand1_alu;
    logic [31:0] operand2_alu;
    logic [ROB_IDX_WIDTH-1:0] dest_ROB_out_alu;
    logic [2:0]  alu_op_out_alu;
    logic [1:0]  rd_type_out_alu;

    //RS Signals
    ResStationCmp_i entries_interface_cmp;
    logic rs_ready_cmp;
    
    logic FU_running_cmp;
    logic issue_cmp;
    logic [31:0] operand1_cmp;
    logic [31:0] operand2_cmp;
    logic [ROB_IDX_WIDTH-1:0] dest_ROB_out_cmp;
    logic   cmp_type_out;   //Jump or Branch
    logic [2:0] cmp_op_out;
    logic [31:0] imm_val_out;
    logic [31:0] pc_val_out;

    
    //RS Signals
    ResStationMult_i entries_interface_mul;
    logic rs_ready_mul;
    
    logic FU_running_mul;
    logic issue_mul;
    logic [31:0] operand1_mul;
    logic [31:0] operand2_mul;
    logic [ROB_IDX_WIDTH-1:0] dest_ROB_out_mul;
    logic [1:0]  alu_op_out_mul;
    logic        div_op_type,upper_out;
    logic [ROB_IDX_WIDTH-1:0] store_ROB_mul_idx, store_ROB_div_idx;
    logic                     store_upper_out;

    //RS Signals
    ResStationDiv_i entries_interface_div;
    logic rs_ready_div;

    logic FU_running_div;
    logic issue_div;
    logic [31:0] operand1_div;
    logic [31:0] operand2_div;
    logic [ROB_IDX_WIDTH-1:0] dest_ROB_out_div;

    mem_rvfi store_rvfi;

    logic ld_rs_ready, st_rs_ready;
    logic ld_dispatch, st_dispatch;
    logic branch_dispatched;
    ResEntryLd_reg_t ld_rs_interface;
    ResEntrySt_reg_t st_rs_interface;

    logic st_commit_flag;
    logic ld_busy, ld_issue;
    logic st_busy, st_issue;
    ResEntryLd_reg_t ld_issue_entry;
    ResEntrySt_reg_t st_issue_entry;

    logic ldst_complete;
    logic [31:0] ldst_result;
    logic [ROB_IDX_WIDTH-1:0] ldst_ROB;
    logic ldst_result_taken;

    //ROB Signals 
    logic                   rob_enqueue;
    ROBentry_t              rob_enqueue_wdata;
    logic                   ready_to_dequeue;
    ROBentry_t              rob_dequeue_rdata;
    logic                   rob_full;
    logic                   rob_empty;
    logic [ROB_IDX_WIDTH - 1: 0]  rs1_ROB_idx, rs2_ROB_idx;
    ROBinfo_t       rs1_ROB_info, rs2_ROB_info;
    logic [ROB_IDX_WIDTH - 1: 0]  rob_idx, dequeued_rob_idx;
    logic store_commit, load_wb;

    //Reg File Signals
    logic           regf_rob_we;
    ROBinfo_t       rob_info;

    logic           regf_we;
    RegFile_t       rd_v;

    logic   [4:0]   rs1_s, rs2_s, rd_s, rd_dis;

    RegFile_t       rs1_v; 
    RegFile_t       rs2_v;
    
    logic   [4:0]   rs1_s_rvfi, rs2_s_rvfi;

    RegFile_t       rs1_v_rvfi, rs2_v_rvfi;

    //ALU Signal
    logic [ROB_IDX_WIDTH-1:0] alu_ROB_out;
    logic [31:0] alu_result;
    logic alu_valid;
    logic alu_busy, cmp_busy, mul_busy, div_busy;

    //Mult Signal
    logic [63:0] mul_result;
    logic done, done_div;
    logic [31:0] cdb_mul, div_result;
    op_type function_type;

    //CMP Signals
    logic [ROB_IDX_WIDTH-1:0] cmp_ROB_out;
    logic [31:0] cmp_result, new_pc_addr;
    logic cmp_valid, branch_taken;

    //CDB Signals
    logic ALU_result_taken, CMP_result_taken, MUL_result_taken, DIV_result_taken;

    logic mul_flushed, div_flushed;

    branch_tag_t cmp_br_tag, flush_tag, alu_br_tag, mul_br_tag, div_br_tag, alu_br_o, cmp_br_o, mul_br_o, ldst_br_o, br_ld, div_br_o;
    mem_rvfi ld_rvfi;

    assign FU_running_alu = alu_busy;
    assign FU_running_cmp = cmp_busy;
    assign FU_running_mul = mul_busy;
    assign FU_running_div = div_busy;

    // always_ff @(posedge clk) begin
    //     if(rst || mul_flushed) begin
    //         FU_running_mul <= 1'b0;
    //     end
    //     else if(issue_mul) begin
    //         FU_running_mul <= 1'b1;
    //     end
    //     else if(FU_running_mul && done) begin
    //         FU_running_mul <= 1'b0;
    //     end
    // end

    assign imem_rmask = 4'b1111;
    assign temp_rdata = dmem_rdata;
    assign temp_resp = dmem_resp;
    assign inst_queue_i.stall = full;
    assign stall_dec_dis = rob_full || (((function_type == alu_op) && !rs_ready_alu) || ((function_type == div_op) && !rs_ready_div) || ((function_type == mul_op) && !rs_ready_mul) || (((function_type == brn_op) || (function_type == jmp_op)) && !rs_ready_cmp) || (!ld_rs_ready) || (!st_rs_ready));
    assign dequeue = (!stall_dec_dis) && (!empty);
 
    queue #(.NUM_ENTRIES(16), .DATA_WIDTH(65)) inst_queue (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .stall(stall_dec_dis),
        .enqueue(inst_queue_i.valid),
        .enqueue_wdata(enqueue_wdata),
        .dequeue(dequeue),
        .dequeue_rdata(dequeue_rdata),
        .full(full),
        .empty(empty)
    );

    rob_buffer #(.NUM_ENTRIES(ROB_ENTRIES)) rob (
        .clk(clk),
        .rst(rst),
        .enqueue(rob_enqueue),
        .enqueue_wdata(rob_enqueue_wdata),
        .dequeue_rdata(rob_dequeue_rdata),
        .full(rob_full),
        .empty(rob_empty),
        .rob_idx(rob_idx),
        .rs1_rob_idx(rs1_ROB_idx),
        .rs2_rob_idx(rs2_ROB_idx),
        .rs1_ROB_info(rs1_ROB_info),
        .rs2_ROB_info(rs2_ROB_info),
        .cdb_input(CDB_values),
        .ready_to_dequeue(ready_to_dequeue),
        .dequeued_rob_idx(dequeued_rob_idx),
        .is_store(store_commit),
        .*
    );
    
    always_ff @(posedge clk) begin
        if(ready_to_dequeue) begin
            regf_we <= 1'b1;
        end else begin
            regf_we <= 1'b0;
        end
    end
    always_comb begin
        if(regf_we) begin
            rd_s = rob_dequeue_rdata.dest_reg;
            rd_v.reg_value = rob_dequeue_rdata.comp_val;
            rd_v.ROB_idx = dequeued_rob_idx;
            rd_v.ROB_busy = 1'b0;
            rd_v.ROB_br_tag = 'x;
        end
        else begin
            rd_s = 'x;
            rd_v.reg_value = 'x;
            rd_v.ROB_idx = 'x;
            rd_v.ROB_busy = 'x;
            rd_v.ROB_br_tag = 'x;
        end
    end


    ResStation_m #(.size(RS_SIZE), .ROB_WIDTH(ROB_IDX_WIDTH)) ResStationALU(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .entries_interface(entries_interface_alu),
        .rs_ready(rs_ready_alu),
        .CDB_value(CDB_values),
        .FU_running(FU_running_alu),
        .issue(issue_alu),
        .commit_taken(ALU_result_taken),
        .operand1(operand1_alu),
        .operand2(operand2_alu),
        .br_tag_out(alu_br_tag),
        .dest_ROB_out(dest_ROB_out_alu),
        .alu_op_out(alu_op_out_alu),
        .rd_type_out(rd_type_out_alu),
        .br_tag(flush_tag)
    );

    ResStationMul_m #(.size(RS_SIZE), .ROB_WIDTH(ROB_IDX_WIDTH)) ResStationMul(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .entries_interface(entries_interface_mul),
        .rs_ready(rs_ready_mul),
        .CDB_value(CDB_values),
        .FU_running(FU_running_mul),
        .issue(issue_mul),
        .operand1(operand1_mul),
        .operand2(operand2_mul),
        .br_tag_out(mul_br_tag),
        .dest_ROB_out(dest_ROB_out_mul),
        .mul_type(alu_op_out_mul),
        .upper(upper_out),
        .*
    );

    ResStationDiv_m #(.size(RS_SIZE), .ROB_WIDTH(ROB_IDX_WIDTH)) ResStationDiv(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .entries_interface(entries_interface_div),
        .rs_ready(rs_ready_div),
        .CDB_value(CDB_values),
        .FU_running(FU_running_div),
        .issue(issue_div),
        .operand1(operand1_div),
        .operand2(operand2_div),
        .br_tag_out(div_br_tag),
        .dest_ROB_out(dest_ROB_out_div),
        .div_op_type(div_op_type),
        .*
    );  

    ResStationCmp_m #(.size(RS_SIZE), .ROB_WIDTH(ROB_IDX_WIDTH)) ResStationCmp(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .flush_tag(flush_tag),
        .entries_interface(entries_interface_cmp),
        .rs_ready(rs_ready_cmp),
        .CDB_value(CDB_values),
        .FU_running(FU_running_cmp),
        .issue(issue_cmp),
        .commit_taken(CMP_result_taken),
        .operand1(operand1_cmp),
        .operand2(operand2_cmp),
        .br_tag_out(cmp_br_tag),
        .dest_ROB_out(dest_ROB_out_cmp),
        .cmp_type_out(cmp_type_out),
        .cmp_op_out(cmp_op_out),
        .imm_val_out(imm_val_out),
        .pc_val_out(pc_val_out)
    );

    ResStation_ld_m #(.size(4), .ROB_WIDTH(ROB_IDX_WIDTH)) ld_RS(
        .st_committed(st_commit_flag),
        .entry_in(ld_rs_interface),
        .read_en(ld_dispatch),
        .rs_ready(ld_rs_ready),
        .CDB_value(CDB_values),
        .FU_running(ld_busy),
        .issue(ld_issue),
        .entry_out(ld_issue_entry),
        .rst(rst),
        .*
    );

    ResStation_st_m #(.size(4), .ROB_WIDTH(ROB_IDX_WIDTH)) st_RS(
        .entry_in(st_rs_interface),
        .read_en(st_dispatch),
        .rs_ready(st_rs_ready),
        .CDB_value(CDB_values),
        .FU_running(st_busy),
        .issue(st_issue),
        .entry_out(st_issue_entry),
        .store_commit(store_commit),
        .store_rvfi(store_rvfi),
        .br_tag(flush_tag),
        .*
    );

    regfile regfile(
        .ROB_commit(regf_we),
        .dispatch_enqueue(regf_rob_we),
        .*
    );

    ifetch_m fetch (
        .clk(clk),
        .rst(rst),
        
        .flush(flush),
        .ext_pc(new_pc_addr),

        .stall(inst_queue_i.stall),
        .imem_addr(imem_addr),
        .imem_resp(imem_resp),
        .imem_rdata(imem_rdata),

        .inst(inst),
        .valid(inst_queue_i.valid),
        .pc_o(pc)
    );

    idecode_m decode(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .valid(dequeue_rdata[0]),
        .in(dequeue_rdata[64:33]),
        .pc(dequeue_rdata[32:1]),   
        .stall(stall_dec_dis),

        .decode_out(decoded_inst),
    
        .rvfi_out(rvfi_pipeline)
    );

    dispatch_m dispatch(
        //Input
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .stall(stall_dec_dis),
        .rob_full(rob_full),
        .decode_in(decoded_inst),  
        .rvfi_in(rvfi_pipeline),
        .rs1_ROB_info(rs1_ROB_info),
        .rs2_ROB_info(rs2_ROB_info),
        .CDB_value(CDB_values),
        //Output
        .rob_enqueue(rob_enqueue),
        .rob_enqueue_wdata(rob_enqueue_wdata),
        .rob_idx(rob_idx),
        .function_type(function_type),
        .rs_ready_ld(ld_rs_ready),
        .rs_ready_st(st_rs_ready),
        .entries_interface_ld(ld_rs_interface),
        .entries_interface_st(st_rs_interface),
        .st_committed(st_commit_flag),
        .rs1_rob_idx(rs1_ROB_idx),
        .rs2_rob_idx(rs2_ROB_idx),
        .*
    );
    
    always_comb begin
        if(done) begin
            if(store_upper_out) cdb_mul = mul_result[63:32];
            else cdb_mul = mul_result[31:0];
        end
        else begin
            cdb_mul = 'x;
        end
    end
    
    cdb #(.ROB_WIDTH(ROB_IDX_WIDTH)) cdb(
        .alu_result(alu_result),
        .alu_valid(alu_valid),
        .dest_ROB_in(alu_ROB_out),
        .alu_br_tag(alu_br_o),
        .ALU_result_taken(ALU_result_taken),

        .mul_result(cdb_mul), //p from multiplier.sv
        .mul_ready(done),
        .mul_br_tag(mul_br_o),
        .dest_ROB_in_mul(store_ROB_mul_idx),
        .MUL_result_taken(MUL_result_taken),

        .div_result(div_result), //p from divider.sv
        .div_ready(done_div),
        .div_br_tag(div_br_o),
        .dest_ROB_in_div(store_ROB_div_idx),
        .DIV_result_taken(DIV_result_taken),

        .cmp_result(cmp_result),
        .pc_addr(new_pc_addr),
        .branch_taken(branch_taken),
        .cmp_br_tag(cmp_br_o),
        .cmp_valid(cmp_valid),
        .dest_ROB_in_cmp(cmp_ROB_out),
        .CMP_result_taken(CMP_result_taken),

        .ldst_ready(ldst_complete),
        .ldst_result(ldst_result),
        .ldst_br_tag(ldst_br_o),
        .ld_rvfi(ld_rvfi),
        .dest_ROB_in_ldst(ldst_ROB),
        .ldst_result_taken(ldst_result_taken),

        .commit_valid(commit_valid),

        .CDB_output(CDB_values)
    );

    

    mem_exe_m mem_exe(
        .ld_entry(ld_issue_entry),
        .st_entry(st_issue_entry),
        .complete(ldst_complete),
        .result(ldst_result),
        .br_tag_out(ldst_br_o),
        .dest_ROB(ldst_ROB),
        .ld_rvfi(ld_rvfi),
        .ld_result_taken(ldst_result_taken),
        .st_committed(st_commit_flag),
        .*
    );

    alu_unit #(.ROB_WIDTH(ROB_IDX_WIDTH)) alu(
        .clk(clk),
        .rst(rst),
        .alu_operation(alu_op_out_alu),
        .issue_in(issue_alu),
        .alu_rd_type(rd_type_out_alu),
        .br_tag_in(alu_br_tag),
        .br_tag_out(alu_br_o),
        .dest_ROB_in(dest_ROB_out_alu), //from RS, whatever that variable is
        .a_in(operand1_alu),
        .b_in(operand2_alu),
        .result_taken(ALU_result_taken),
        .busy(alu_busy),
        .alu_result(alu_result),
        .alu_valid(alu_valid),
        .dest_ROB_out_ALU(alu_ROB_out)
    );

    cmp #(.ROB_WIDTH(ROB_IDX_WIDTH)) cmp(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .issue_in(issue_cmp), //ready
        .cmp_type_in(cmp_type_out),    //Jump or Branch
        .cmp_op_in(cmp_op_out),
        .br_tag_in(cmp_br_tag),
        .br_tag_out(cmp_br_o),
        .imm_val_in(imm_val_out),
        .pc_val_in(pc_val_out),
        .dest_ROB_in(dest_ROB_out_cmp),
        .a_in(operand1_cmp), .b_in(operand2_cmp), //operands
        .result_taken(CMP_result_taken),
        .busy(cmp_busy),
        .cmp_result(cmp_result),
        .pc_addr(new_pc_addr),
        .branch_taken(branch_taken),
        .cmp_valid(cmp_valid),
        .dest_ROB_out_CMP(cmp_ROB_out)
    );

    jump_ctrl_m jump_ctrl(
        .is_jump(branch_taken),
        .jump_tag(cmp_br_o),
        .flush(flush),
        .flush_tag(flush_tag)
    );

    dadda_multiplier dadda_multiplier_unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .flush_tag(flush_tag),
        .br_tag(mul_br_tag),
        .br_tag_out(mul_br_o),
        .start(issue_mul),
        .busy(mul_busy),
        .mul_type(alu_op_out_mul), 
        .a(operand1_mul),
        .b(operand2_mul),
        .p(mul_result),
        .done(done),
        .flush_valid(mul_flushed),
        .*
    );

    divider divider_unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .flush_tag(flush_tag),
        .br_tag(div_br_tag),
        .br_tag_out(div_br_o),
        .start(issue_div),
        .busy(div_busy),
        .div_type(div_op_type), 
        .a(operand1_div),
        .b(operand2_div),
        .division_result(div_result),
        .done(done_div),
        .flush_valid(div_flushed),
        .*
    );

    always_ff @(posedge clk) begin
        if(issue_mul) begin 
            store_ROB_mul_idx <= dest_ROB_out_mul;
            store_upper_out <= upper_out;
        end
        if(issue_div) begin 
            store_ROB_div_idx <= dest_ROB_out_div;
        end
    end

    assign enqueue_wdata = {inst, pc, inst_queue_i.valid};
    
    logic [63:0] order;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            order <= '0;
        end
        else if(regf_we) begin
            order <= order + 1'b1;
        end
    end
    always_comb begin
        if(regf_we) begin
            rs1_s_rvfi = rob_dequeue_rdata.RVFI.rs1_addr;
            rs2_s_rvfi = rob_dequeue_rdata.RVFI.rs2_addr;
            rvfi.valid     = rob_dequeue_rdata.RVFI.valid;
            rvfi.inst      = rob_dequeue_rdata.RVFI.inst;
            rvfi.order     = order;
            rvfi.rs1_addr  = rob_dequeue_rdata.RVFI.rs1_addr;
            rvfi.rs2_addr  = rob_dequeue_rdata.RVFI.rs2_addr;
            rvfi.rs1_rdata = rs1_v_rvfi.reg_value;
            rvfi.rs2_rdata = rs2_v_rvfi.reg_value;
            rvfi.rd_addr   = rd_s;
            rvfi.rd_wdata  = (rd_s != 5'd0) ? rd_v.reg_value : '0;
            rvfi.pc_rdata  = rob_dequeue_rdata.RVFI.pc_rdata;
            rvfi.pc_wdata  = rob_dequeue_rdata.RVFI.pc_wdata;

            if (rob_dequeue_rdata.is_store) begin
                rvfi.mem_addr = store_rvfi.mem_addr;
                rvfi.mem_rmask = store_rvfi.mem_rmask;
                rvfi.mem_rdata = store_rvfi.mem_rdata;
                rvfi.mem_wmask = store_rvfi.mem_wmask;
                rvfi.mem_wdata = store_rvfi.mem_wdata;
            end else begin
                rvfi.mem_addr = rob_dequeue_rdata.RVFI.mem_addr;
                rvfi.mem_rmask = rob_dequeue_rdata.RVFI.mem_rmask;
                rvfi.mem_rdata = rob_dequeue_rdata.RVFI.mem_rdata;
                rvfi.mem_wmask = rob_dequeue_rdata.RVFI.mem_wmask;
                rvfi.mem_wdata = rob_dequeue_rdata.RVFI.mem_wdata;
            end 
        end
        else begin
            rs1_s_rvfi = 'x;
            rs2_s_rvfi = 'x;
            rvfi.valid     = '0;
            rvfi.inst      = 'x;
            rvfi.order     = 'x;
            rvfi.rs1_addr  = 'x;
            rvfi.rs2_addr  = 'x;
            rvfi.rs1_rdata = 'x;
            rvfi.rs2_rdata = 'x;
            rvfi.rd_addr   = 'x;
            rvfi.rd_wdata  = 'x;
            rvfi.pc_rdata  = 'x;
            rvfi.pc_wdata  = 'x;
            rvfi.mem_addr = 'x;
            rvfi.mem_rmask = 'x;
            rvfi.mem_rdata = 'x;
            rvfi.mem_wmask = 'x;
            rvfi.mem_wdata = 'x;
        end

    end
    
endmodule : cpu
