module mem_exe_m 
import rv32i_types::*; 
(
    input logic clk,
    input logic rst,

    input logic ld_issue,
    input ResEntryLd_reg_t ld_entry,
    output logic ld_busy,

    input logic st_issue,
    input ResEntrySt_reg_t st_entry,
    output logic st_busy,

    /* CDB Interface*/
    output logic complete,
    output logic [31:0] result,
    output branch_tag_t br_tag_out,
    output logic [ROB_WIDTH_-1:0] dest_ROB,
    output mem_rvfi ld_rvfi,
    input logic ld_result_taken,

    output logic st_committed,

    /* Mem Interface*/
    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp
);

datastore_state_t state, next_state;
ResEntryLd_reg_t ld_info_reg;
ResEntrySt_reg_t st_info_reg;
CDB_output_t to_CDB_cached;
logic load_info_ready, store_info_ready;
branch_tag_t br_reg;

logic [31:0] target_addr;
logic [1:0] shift_bits, shift_bits_reg;
logic ld_signed, ld_signed_reg;

logic [3:0] r_mask;
logic [31:0] mask, b_mask, n_mask;
logic [31:0] signed_v;

logic [31:0] value;
logic [31:0] addr_reg;
logic [31:0] rdata_reg;



assign shift_bits = target_addr[1:0];
assign value = dmem_rdata >> 8 * shift_bits_reg;
assign mask = {8'(signed'(r_mask[3])), 8'(signed'(r_mask[2])), 8'(signed'(r_mask[1])), 8'(signed'(r_mask[0]))} >> 8 * shift_bits_reg;
assign n_mask = ~mask;
assign b_mask = (mask + 32'b1) >> 1;
assign signed_v = {32'(signed'((value & b_mask) != 0))};
assign ld_rvfi = {addr_reg, r_mask, rdata_reg, 4'b0, 32'bx};

always_ff @(posedge clk) begin
    if (rst) begin
        ld_info_reg <= '0;
        st_info_reg <= '0;
        ld_signed_reg <= '0;
        load_info_ready <= '0;
        store_info_ready <= '0;
        to_CDB_cached <= '0;
        shift_bits_reg <= '0;
        rdata_reg <= '0;
        state <= idle;

    end else begin
        state <= next_state;

        if (ld_issue) begin
            load_info_ready <= 1'b1;
            ld_info_reg <= ld_entry;
        end else begin
            load_info_ready <= load_info_ready && (state != commit);
        end 
        if (st_issue) begin
            store_info_ready <= 1'b1;
            st_info_reg <= st_entry;
        end else begin
            store_info_ready <= store_info_ready && !(state == waiting_st && next_state != waiting_st);
        end

        if (next_state == commit && state != commit) begin
            to_CDB_cached.dest_ROB <= (state == waiting_ld) ? ld_info_reg.dest_ROB_in : st_info_reg.dest_ROB_in;
            to_CDB_cached.rd_v <= (state == waiting_ld) ? (ld_signed_reg ? (value & mask) + (signed_v & n_mask) : value & mask) : '0;
            to_CDB_cached.br_tag <= (state == waiting_ld) ? ld_info_reg.br_tag : st_info_reg.br_tag;
            rdata_reg <= dmem_rdata;
        end  
        if (next_state == waiting_ld) begin
            br_reg <= ld_info_reg.br_tag;
            r_mask <= dmem_rmask;
            shift_bits_reg <= shift_bits;
            ld_signed_reg <= ld_signed;
            addr_reg <= dmem_addr;
        end 
    end 
    
end 

always_comb begin
    dmem_addr = 'x;
    dmem_rmask = '0;
    dmem_wmask = '0;
    dmem_wdata = 'x;

    target_addr = 'x;

    ld_busy = load_info_ready;
    st_busy = store_info_ready;
    complete = 1'b0;
    result = 'x;
    dest_ROB = 'x;
    st_committed = (state == waiting_st) && dmem_resp;
    ld_signed = 'x;
    br_tag_out = 'x;

    unique case (state)
        idle: begin
            /* Prioritize load*/
            next_state = (load_info_ready || store_info_ready) ? (load_info_ready ? waiting_ld : waiting_st) : idle;
        end  
        waiting_ld: begin
            next_state = dmem_resp ? commit : waiting_ld;
        end 
        waiting_st: begin
            next_state = dmem_resp ? idle : waiting_st;
        end 
        commit: begin
            next_state = ld_result_taken ? idle : commit;
        end 
        default: next_state = idle;
    endcase
    
    if (next_state == waiting_ld) begin
        target_addr = ld_info_reg.rs1_data + ld_info_reg.imm_value;
        dmem_addr = {target_addr[31:2], 2'b0};

        unique case (ld_info_reg.funct3)
            lb, lbu: dmem_rmask = 4'b0001 << shift_bits;
            lh, lhu: begin 
                dmem_rmask = 4'b0011 << shift_bits; 
            end
            lw:      begin 
                dmem_rmask = 4'b1111;
            end
            default: dmem_rmask = 'x;
        endcase
        
        unique case (ld_info_reg.funct3)
            lb, lh, lw: ld_signed = 1'b1;
            lbu, lhu:   ld_signed = 1'b0;
            default: ld_signed = 1'bx;
        endcase
        ld_busy = !dmem_resp;
    end else if (next_state == waiting_st) begin
        target_addr = st_info_reg.rs1_data + st_info_reg.imm_value;
        dmem_addr = {target_addr[31:2], 2'b0};

        unique case (st_info_reg.funct3)
            sb: dmem_wmask = 4'b0001 << shift_bits[1:0];
            sh: begin
                dmem_wmask = 4'b0011 << shift_bits[1:0];
            end
            sw: begin
                dmem_wmask = 4'b1111;
            end
            default: dmem_wmask = 'x;
        endcase
        unique case (st_info_reg.funct3)
            sb: dmem_wdata[8 *shift_bits[1:0] +: 8 ] = st_info_reg.rs2_data[7 :0];
            sh: dmem_wdata[16*shift_bits[1]   +: 16] = st_info_reg.rs2_data[15:0];
            sw: dmem_wdata = st_info_reg.rs2_data;
            default: dmem_wdata = 'x;
        endcase
    end

    if (state == commit) begin
        complete = 1'b1;
        result = to_CDB_cached.rd_v;
        dest_ROB = to_CDB_cached.dest_ROB;
        br_tag_out = to_CDB_cached.br_tag;
    end 
end


endmodule

// module transparent_queue 
// import rv32i_types::*;
// #(
//             parameter               NUM_ENTRIES = 8,
//             parameter               DATA_WIDTH  = 104,
//             parameter               KEY_WIDTH = ROB_WIDTH_ + 9
// )
// (
//     input   logic                   clk,
//     input   logic                   rst,
//     input   logic                   flush,
//     input   branch_tag_t            flush_br_tag,

//     input   logic                   enqueue,
//     input   logic [KEY_WIDTH-1:0]   enqueue_key,
//     input   logic [DATA_WIDTH-1:0]  enqueue_wdata,

//     input   logic                   dequeue,
//     input   logic [KEY_WIDTH-1:0]   dequeue_key,
//     output  logic [DATA_WIDTH-1:0]  dequeue_rdata,

//     output  logic                   full,
//     output  logic                   empty
// );

//     localparam              Q_INDEX    =  $clog2(NUM_ENTRIES);

//     mem_rvfi     entries [NUM_ENTRIES];

//     logic   [NUM_ENTRIES-1:0]       entry_empty;
//     logic   [Q_INDEX-1 : 0]     issue_idx;

//     assign full = 1'b0;
//     assign empty = 1'b0;

//     always_ff @(posedge clk) begin
//         if(rst) begin
//             entry_empty <= '1;
//             for (int i = 0; i < NUM_ENTRIES; i++) begin
//                 entries[i] <= '0;
//             end
//         end
//         else begin
//             //Enqueue
//             if(enqueue) begin
//                 for (int i = 0; i < NUM_ENTRIES; i++) begin
//                     /* entry_empty updated at clock edge, meaning entry issued last cycle wouldn't be 
//                        marked as empty when new entry comes in. Thus the i == issue_idx check */
//                     if (entry_empty[i])begin
//                         entries[i] <= {enqueue_key, enqueue_wdata};
//                         entry_empty[i] <= 1'b0;
//                         if (issue_idx != Q_INDEX'(signed'(1'b1)))
//                             entry_empty[issue_idx] <= 1'b1;
//                         break;
//                     end else if (Q_INDEX'(i) == issue_idx) begin
//                         entries[i] <= {enqueue_key, enqueue_wdata};
//                         entry_empty[i] <= 1'b0;
//                         break;
//                     end
//                 end 
//             end else begin
//                 if (issue_idx != Q_INDEX'(signed'(1'b1))) begin
//                     entry_empty[issue_idx] <= 1'b1;
//                 end
//             end 
//         end
//     end

//     always_comb begin
//         dequeue_rdata = 'x;
//         issue_idx = Q_INDEX'(signed'(1'b1));
//         for (int i = 0; i < NUM_ENTRIES; i++) begin
//             if (({entries[i].ROB_idx, entries[i].br_tag} == dequeue_key) && !entry_empty[i] && dequeue) begin
//                 dequeue_rdata = entries[i][DATA_WIDTH-1:0];
//                 issue_idx = Q_INDEX'(i);
//                 break;
//             end 
//         end 
//     end


// endmodule : transparent_queue