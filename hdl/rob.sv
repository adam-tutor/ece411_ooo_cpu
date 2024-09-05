module rob_buffer 
import rv32i_types::*;
#(
            parameter               NUM_ENTRIES = 16
)
(
    input   logic                   clk,
    input   logic                   rst,

    input   logic                   enqueue,
    input   ROBentry_t              enqueue_wdata,

    // input   logic                   dequeue,

    /* Reg related signal*/
    output  logic                   ready_to_dequeue,
    output  logic [$clog2(NUM_ENTRIES) - 1:0]     dequeued_rob_idx,
    output  ROBentry_t              dequeue_rdata,

    output  logic                   full,
    output  logic                   empty,
    

    /* Dispatch interface for operand retrieving */
    input  logic [rob_idx_bits-1:0]    rs1_rob_idx,
    input  logic [rob_idx_bits-1:0]    rs2_rob_idx,
    output ROBinfo_t      rs1_ROB_info,
    output ROBinfo_t      rs2_ROB_info,
    /* dest_rob idx for enqueued inst */
    output  logic [$clog2(NUM_ENTRIES) - 1: 0]  rob_idx,

    input CDB_output_t cdb_input,

    output logic commit_valid,

    output  logic is_store
);

    localparam              Q_INDEX    =  $clog2(NUM_ENTRIES);
    localparam              ptr_width = Q_INDEX+1;

    logic                   entry_valid [NUM_ENTRIES];
    ROBentry_t              entries [NUM_ENTRIES];
    ROBentry_t              wdata_buf;

    logic   [Q_INDEX:0]     head_ptr;
    logic   [Q_INDEX:0]     tail_ptr;

    // From Lab Slides
    assign full = (
        (head_ptr[Q_INDEX-1:0] == tail_ptr[Q_INDEX-1:0]) &&
        (head_ptr[Q_INDEX] != tail_ptr[Q_INDEX])
    );
    assign empty = (head_ptr == tail_ptr);


    always_ff @(posedge clk) begin
        if(rst) begin
            head_ptr <= '0;
            tail_ptr <= '0;
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i] <= '0;
                entry_valid[i] <= '0;
            end
            is_store <= 1'b0;
        end
        else begin
            /* When CDB data is valid and match ROB entry's state */
            if (cdb_input.commit_valid && cdb_input.br_tag == entries[cdb_input.dest_ROB].br_tag && entry_valid[cdb_input.dest_ROB]) begin
                entries[cdb_input.dest_ROB].ready <= 1'b1;
                entries[cdb_input.dest_ROB].comp_val <= cdb_input.rd_v;
                entries[cdb_input.dest_ROB].branch_taken <= cdb_input.branch_taken;

                /* Insert memory rvfi info if it is load instr  */
                if (entries[cdb_input.dest_ROB].is_load) begin
                    entries[cdb_input.dest_ROB].RVFI.mem_addr <= cdb_input.ld_rvfi.mem_addr;
                    entries[cdb_input.dest_ROB].RVFI.mem_rmask <= cdb_input.ld_rvfi.mem_rmask;
                    entries[cdb_input.dest_ROB].RVFI.mem_rdata <= cdb_input.ld_rvfi.mem_rdata;
                    entries[cdb_input.dest_ROB].RVFI.mem_wmask <= cdb_input.ld_rvfi.mem_wmask;
                    entries[cdb_input.dest_ROB].RVFI.mem_wdata <= cdb_input.ld_rvfi.mem_wdata;
                end 

                // Flush condition met, clear younger entries (Is clearing data needed after marking entry as empty?)
                if (cdb_input.branch_taken && entries[cdb_input.dest_ROB].is_branch) begin
                    entries[cdb_input.dest_ROB].RVFI.pc_wdata <= cdb_input.jump_pc;
                    for (int i = 0; i < NUM_ENTRIES; i++) begin
                        /* branch tag comparison logic */
                        if (entries[i].br_tag.sign == cdb_input.br_tag.sign) begin
                            if ((entries[i].br_tag.tag & cdb_input.br_tag.tag) == cdb_input.br_tag.tag) begin
                                if (unsigned'(rob_idx_bits'(i)) == cdb_input.dest_ROB) begin
                                end else begin
                                    entries[i] <= '0;
                                    entry_valid[i] <= '0;
                                end 
                            end
                        end else begin
                            if ((entries[i].br_tag.tag & cdb_input.br_tag.tag) == entries[i].br_tag.tag) begin
                                entries[i] <= '0;
                                entry_valid[i] <= '0;
                            end 
                        end 
                    end
                end 
            end 

            // Flush & enqueue
            if(cdb_input.commit_ready && cdb_input.br_tag == entries[cdb_input.dest_ROB].br_tag && cdb_input.branch_taken && entries[cdb_input.dest_ROB].is_branch) begin
                tail_ptr <= {entries[cdb_input.dest_ROB].sign, cdb_input.dest_ROB} + ptr_width'(1);
            end else begin
                if(enqueue && (full == '0)) begin
                    tail_ptr <= tail_ptr + ptr_width'(1);
                    entries[tail_ptr[Q_INDEX-1:0]] <= wdata_buf;
                    entry_valid[tail_ptr[Q_INDEX-1:0]] <= '1;
                end
            end 
            
            //Dequeue
            if(ready_to_dequeue && (empty == '0)) begin
                dequeue_rdata <= entries[head_ptr[Q_INDEX-1:0]];
                entry_valid[head_ptr[Q_INDEX-1:0]] <= 1'b0;
                head_ptr <= head_ptr + 1'b1;
                dequeued_rob_idx <= head_ptr[Q_INDEX-1:0];
                is_store <= entries[head_ptr[Q_INDEX-1:0]].is_store;
            end else begin
                is_store <= 1'b0;
            end

            
        end
    end
    always_comb begin
        // Save tail sign bit so that tail ptr can be restored when flushing
        wdata_buf = enqueue_wdata;
        wdata_buf.sign = tail_ptr[Q_INDEX];

        if(enqueue && (full == '0)) begin
            rob_idx = tail_ptr[Q_INDEX-1:0];
        end
        else begin
            rob_idx = 'x;
        end

        if(entries[head_ptr[Q_INDEX-1:0]].ready && (empty == '0)) begin
            ready_to_dequeue = 1'b1;
        end
        else begin
            ready_to_dequeue = 1'b0;
        end

        if (cdb_input.commit_ready && cdb_input.br_tag == entries[cdb_input.dest_ROB].br_tag && entry_valid[cdb_input.dest_ROB]) begin
            commit_valid = 1'b1;
        end else begin
            commit_valid = 1'b0;
        end 
    end
 
    always_comb begin
        rs1_ROB_info.ROB_busy = !entries[rs1_rob_idx].ready;
        rs1_ROB_info.ROB_idx = 'x;
        rs1_ROB_info.value = entries[rs1_rob_idx].comp_val;

        rs2_ROB_info.ROB_busy = !entries[rs2_rob_idx].ready;
        rs2_ROB_info.ROB_idx = 'x;
        rs2_ROB_info.value = entries[rs2_rob_idx].comp_val;
    end

endmodule : rob_buffer