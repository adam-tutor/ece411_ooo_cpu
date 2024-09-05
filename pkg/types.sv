package rv32i_types;

    localparam st_qsize = 4;
    localparam st_qidx_w = 2;
    localparam rob_idx_bits = $clog2(8);
    localparam ROB_WIDTH_ = rob_idx_bits;

    typedef enum logic [6:0] {
        op_b_lui   = 7'b0110111, // U load upper immediate 
        op_b_auipc = 7'b0010111, // U add upper immediate PC 
        op_b_jal   = 7'b1101111, // J jump and link 
        op_b_jalr  = 7'b1100111, // I jump and link register 
        op_b_br    = 7'b1100011, // B branch 
        op_b_load  = 7'b0000011, // I load 
        op_b_store = 7'b0100011, // S store 
        op_b_imm   = 7'b0010011, // I arith ops with register/immediate operands 
        op_b_reg   = 7'b0110011, // R arith ops with register operands 
        op_b_csr   = 7'b1110011  // I control and status register 
    } rv32i_op_b_t;

    typedef enum logic [2:0] {
        funct3_mul      = 3'b000,  // Lower 32 bits of op
        funct3_mulh     = 3'b001,  // Upper 32 bits of op 
        funct3_mulhsu   = 3'b010,  // Upper 32 bits of op
        funct3_mulhu    = 3'b011,   // Upper 32 bits of op
        funct3_div      = 3'b100,
        funct3_divu     = 3'b101,
        funct3_rem      = 3'b110,
        funct3_remu     = 3'b111
    } mul_b_t;

    typedef enum logic [1:0] {
        sign_sign      = 2'b00, 
        sign_unsign     = 2'b01,   
        unsign_unsign   = 2'b10  
    } mul_type_t;

    typedef enum logic  {
        division_op      = 1'b0, 
        remainder_op     = 1'b1 
    } div_type_t;

    typedef enum logic [6:0] {
        multiply    = 7'b0000001   
    } funct7_mul_t;

     typedef enum logic [2:0] {
        beq  = 3'b000,
        bne  = 3'b001,
        blt  = 3'b100,
        bge  = 3'b101,
        bltu = 3'b110,
        bgeu = 3'b111
    } branch_funct3_t;

    typedef enum logic [2:0] {
        lb  = 3'b000,
        lh  = 3'b001,
        lw  = 3'b010,
        lbu = 3'b100,
        lhu = 3'b101
    } load_funct3_t;

    typedef enum logic [2:0] {
        sb = 3'b000,
        sh = 3'b001,
        sw = 3'b010
    } store_funct3_t;

    typedef enum logic [2:0] {
        add  = 3'b000, //check bit 30 for sub if op_reg opcode
        sll  = 3'b001,
        slt  = 3'b010,
        sltu = 3'b011,
        axor = 3'b100,
        sr   = 3'b101, //check bit 30 for logical/arithmetic
        aor  = 3'b110,
        aand = 3'b111
    } arith_funct3_t;

    typedef enum logic [2:0] {
        alu_add = 3'b000,
        alu_sll = 3'b001,
        alu_sra = 3'b010,
        alu_sub = 3'b011,
        alu_xor = 3'b100,
        alu_srl = 3'b101,
        alu_or  = 3'b110,
        alu_and = 3'b111
    } alu_ops;

    typedef enum logic [2:0] {
        alu_op = 3'b000,
        mul_op = 3'b001,
        jmp_op = 3'b010,
        brn_op = 3'b011,
        div_op = 3'b100,
        misc = 3'b111
    } op_type;
    // Add more things here . . .

    typedef struct packed {
        logic valid;
        logic stall;
    } inst_queue_interface;

    typedef struct packed {
        logic [31:0] inst;
        logic [63:0] order;
        logic valid;
        logic [4:0] rs1_addr;
        logic [4:0] rs2_addr;
        logic [31:0] rs1_rdata;
        logic [31:0] rs2_rdata;
        logic [4:0] rd_addr;
        logic [31:0] rd_wdata;
        logic [31:0] pc_rdata;
        logic [31:0] pc_wdata;
        logic [31:0] mem_addr;
        logic [3:0] mem_rmask;
        logic [3:0] mem_wmask;
        logic [31:0] mem_rdata;
        logic [31:0] mem_wdata;
    } rvfi_signal_t;

    typedef struct packed{
    logic   [31:0]  operand_a;
    logic   [31:0]  operand_b;
    logic   [2:0]   alu_opcode;

    logic   [1:0]   mem_op;
    logic   [2:0]   funct3;
    logic   [6:0]   funct7;

    logic   [31:0]  current_pc;
    logic   [31:0]  imm_val;
    logic   [1:0]   alu_rd_type;
    logic           data_a_is_imm;
    logic           data_b_is_imm;
    
    op_type         function_type;
    logic   [1:0]   mult_type;
    logic           upper;
    
    logic           div_op;
    } decoded_inst_t;

    typedef struct packed{
        logic sign;
        logic [7:0] tag;
    } branch_tag_t;

    typedef struct packed {
        logic [31:0] mem_addr;
        logic [3:0] mem_rmask;
        logic [31:0] mem_rdata;
        logic [3:0] mem_wmask;
        logic [31:0] mem_wdata;
    } mem_rvfi;

    typedef struct packed {
        // ROB -> instruction type, result ready signal, destination register, computed value, RVFI data
        logic ready;
        logic [63:0] inst_type;
        logic [63:0] dest_reg;
        logic [31:0] comp_val;
        rvfi_signal_t RVFI;
    } DecodedInst_t;

    typedef struct packed {
        // ROB -> instruction type, result ready signal, destination register, computed value, RVFI data
        logic ready;
        logic [4:0] dest_reg;
        logic [31:0] comp_val;
        logic is_branch;
        logic is_store;
        logic is_load;
        logic branch_taken;
        branch_tag_t br_tag;
        logic sign;
        rvfi_signal_t RVFI;
    } ROBentry_t;


    typedef struct packed {
        logic rs1_ready;
        logic [31:0] rs1_data;
        //logic [rob_idx_bits-1:0] rs1_ROB;
        logic rs2_ready;
        logic [31:0] rs2_data;
        //logic [rob_idx_bits-1:0] rs2_ROB;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB_in;
        logic [2:0] alu_opcode;
        logic [1:0] alu_rd_type;
    } ResEntry_reg_t;

    typedef struct packed {
        logic rs1_ready;
        logic [31:0] rs1_data; 
        logic rs2_ready;
        logic [31:0] rs2_data;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB;
    } ResEntry_base_t;


    typedef struct packed {
        logic rs1_ready;
        logic [31:0] rs1_data;
        logic rs2_ready;
        logic [31:0] rs2_data;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB_in;
        logic   [1:0]   mult_type;
        logic       upper;
    } ResEntryMult_reg_t;

    typedef struct packed {
        logic rs1_ready;
        logic [31:0] rs1_data;
        logic rs2_ready;
        logic [31:0] rs2_data;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB_in;

        logic div_op_out;
    } ResEntryDiv_reg_t;

    typedef struct packed {
        logic rs1_ready;
        logic [31:0] rs1_data;
        logic rs2_ready;
        logic [31:0] rs2_data;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB_in;

        logic   cmp_type;   //Jump or Branch
        logic [2:0] cmp_op;
        logic [31:0] imm_val;
        logic [31:0] pc_val;
    } ResEntryCmp_reg_t;

    typedef struct packed {
        logic [st_qsize-1:0] st_offset; 
        logic rs1_ready;
        logic [31:0] rs1_data;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB_in;
        logic [31:0] imm_value;
        logic [2:0] funct3; 
    } ResEntryLd_reg_t;

    typedef struct packed {
        logic rs1_ready;
        logic [31:0] rs1_data;
        logic rs2_ready;
        logic [31:0] rs2_data;
        branch_tag_t br_tag;
        logic [rob_idx_bits-1:0] dest_ROB_in;
        logic [31:0] imm_value;
        logic [2:0] funct3; 
    } ResEntrySt_reg_t;

    typedef struct packed {
        logic read_dispatch;
        ResEntry_reg_t content;
    } ResStation_i;

    typedef struct packed {
        logic read_dispatch;
        ResEntryMult_reg_t content;
    } ResStationMult_i;

    typedef struct packed {
        logic read_dispatch;
        ResEntryCmp_reg_t content;
    } ResStationCmp_i;

    typedef struct packed {
        logic read_dispatch;
        ResEntryDiv_reg_t content;
    } ResStationDiv_i;

    // Draft CDB output type
    typedef struct packed {
        logic [rob_idx_bits-1:0] dest_ROB;
        logic [31:0] rd_v;
        logic [31:0] jump_pc;
        branch_tag_t br_tag;
        logic branch_taken;
        logic commit_ready;
        logic commit_valid;
        mem_rvfi ld_rvfi;
    } CDB_output_t;

    typedef struct packed {
        logic [31:0] reg_value;
        logic [rob_idx_bits-1:0] ROB_idx;
        logic ROB_busy;
        branch_tag_t ROB_br_tag;
    } RegFile_t;

    typedef struct packed {
        logic [rob_idx_bits-1:0] ROB_idx;
        logic ROB_busy;
    } RegState_t;

    typedef struct packed {
        logic [rob_idx_bits-1:0] ROB_idx;
        logic ROB_busy;
        logic [31:0] value;
        branch_tag_t br_tag;
    } ROBinfo_t;

    typedef struct packed {
        logic [rob_idx_bits-1:0] alu_rs1_rob_idx;
        logic [rob_idx_bits-1:0] alu_rs2_rob_idx;
        logic [rob_idx_bits-1:0] mul_rs1_rob_idx;
        logic [rob_idx_bits-1:0] mul_rs2_rob_idx;
        logic [rob_idx_bits-1:0] cmp_rs1_rob_idx;
        logic [rob_idx_bits-1:0] cmp_rs2_rob_idx;
    } RS_registers_t;

    typedef struct packed {
        ROBentry_t alu_rs1_rob_data;
        ROBentry_t alu_rs2_rob_data;
        ROBentry_t mul_rs1_rob_data;
        ROBentry_t mul_rs2_rob_data;
        ROBentry_t cmp_rs1_rob_data;
        ROBentry_t cmp_rs2_rob_data;
    } RS_data_t;

    typedef enum logic [1:0] {
        idle = 2'b00,
        waiting_ld = 2'b01,
        waiting_st = 2'b10,
        commit = 2'b11
    } datastore_state_t;

     typedef enum logic [1:0]{
        way_0 = 2'b00,
        way_1 = 2'b01,
        way_2 = 2'b10,
        way_3 = 2'b11
     } way_sel_t;

     typedef enum logic [2:0]{
        word0 = 3'b000,
        word1 = 3'b001,
        word2 = 3'b010,
        word3 = 3'b011,
        word4 = 3'b100,
        word5 = 3'b101,
        word6 = 3'b110,
        word7 = 3'b111
     } word_sel_t;

    typedef enum logic [1:0] {
        idle_cache = 2'b00,
        lookup = 2'b01,
        writeback = 2'b10,
        writeAlloc = 2'b11
    } cache_state_t;

endpackage
