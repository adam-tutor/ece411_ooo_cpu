module ResStation_st_m
import rv32i_types::*; 
#(  parameter size = 4,
    parameter ROB_WIDTH = 3
)(
    input logic clk,
    input logic rst,
    input logic flush,
    input branch_tag_t br_tag,
    input logic store_commit,
    
    input ResEntrySt_reg_t entry_in,
    input logic read_en,
    output logic rs_ready,

    input CDB_output_t CDB_value,

    input  logic FU_running,
    output logic issue,
    output ResEntrySt_reg_t entry_out,
    output mem_rvfi store_rvfi
);
    localparam DATA_WIDTH = $bits(ResEntrySt_reg_t);
    localparam Q_INDEX    =  $clog2(size);

    ResEntrySt_reg_t    entries [size];
    logic   [Q_INDEX-1:0] last_idx;

    logic   [Q_INDEX:0]     head_ptr;
    logic   [Q_INDEX:0]     commit_rdy_ptr;
    logic   [Q_INDEX:0]     tail_ptr;
    logic   [Q_INDEX:0]     flush_ptr;
    logic   dequeue;
    logic   empty;
    logic   [31:0]  target_addr_imm;
    logic   [1:0]   shift_bits_imm;
    logic   [3:0]   wmask_imm;
    logic   [31:0]  data_imm;
    logic   commit_valid;


    // From Lab Slides
    assign rs_ready = !(
        (head_ptr[Q_INDEX-1:0] == tail_ptr[Q_INDEX-1:0]) &&
        (head_ptr[Q_INDEX] != tail_ptr[Q_INDEX])
    );
    assign empty = (head_ptr == tail_ptr);
    assign store_rvfi = {target_addr_imm, 4'b0, 32'bx, wmask_imm, data_imm};
    assign commit_valid = commit_rdy_ptr != head_ptr;

    always_ff @(posedge clk) begin
        if(rst) begin
            head_ptr <= '0;
            commit_rdy_ptr <= '0;
            tail_ptr <= '0;
            for (int i = 0; i < size; i++) begin
                entries[i] <= '0;
            end
        end else if (flush) begin
            tail_ptr <= flush_ptr;

            if (store_commit) begin
                commit_rdy_ptr <= commit_rdy_ptr + 1'b1;
            end 
        end else begin
            if (store_commit) begin
                commit_rdy_ptr <= commit_rdy_ptr + 1'b1;
            end 

            //Enqueue
            if (read_en) begin
                entries[tail_ptr[Q_INDEX-1:0]] <= entry_in;
                tail_ptr <= tail_ptr + 1'b1;
            end
            //Dequeue
            if (issue) begin
                head_ptr <= head_ptr + 1'b1;
                entries[head_ptr[Q_INDEX-1:0]] <= '0;
            end

            for (int i = 0; i < size; i++) begin
                if (read_en && unsigned'((Q_INDEX)'(i)) == tail_ptr[Q_INDEX-1:0]) begin
                    if ((!entry_in.rs1_ready) && entry_in.rs1_data[ROB_WIDTH_-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid) begin
                        entries[i].rs1_data <= CDB_value.rd_v;
                        entries[i].rs1_ready <= 1'b1;
                    end
                    if ((!entry_in.rs2_ready) && entry_in.rs2_data[ROB_WIDTH_-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid) begin
                        entries[i].rs2_data <= CDB_value.rd_v;
                        entries[i].rs2_ready <= 1'b1;
                    end
                end else begin
                    if ((!entries[i].rs1_ready) && entries[i].rs1_data[ROB_WIDTH_-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid) begin
                        entries[i].rs1_data <= CDB_value.rd_v;
                        entries[i].rs1_ready <= 1'b1;
                    end
                    if ((!entries[i].rs2_ready) && entries[i].rs2_data[ROB_WIDTH_-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid) begin
                        entries[i].rs2_data <= CDB_value.rd_v;
                        entries[i].rs2_ready <= 1'b1;
                    end
                end
            end
        end
    end

    always_comb begin
        issue = 1'b0;
        entry_out = 'x;

        target_addr_imm = 'x;
        wmask_imm = 'x; 
        data_imm = 'x;
        shift_bits_imm = 'x;
        flush_ptr = tail_ptr;

        if (!empty && !FU_running && entries[head_ptr[Q_INDEX-1:0]].rs1_ready && entries[head_ptr[Q_INDEX-1:0]].rs2_ready && commit_valid) begin
            issue = 1'b1;
            entry_out = entries[head_ptr[Q_INDEX-1:0]];
        end

        if (flush) begin
            if (!empty) begin
                for (int i = 0; i < size; i++) begin
                    flush_ptr = tail_ptr - unsigned'(Q_INDEX'(i)) - unsigned'(Q_INDEX'(1));
                    if (entries[flush_ptr[Q_INDEX-1:0]].br_tag.sign == br_tag.sign) begin
                        if ((entries[flush_ptr[Q_INDEX-1:0]].br_tag.tag & br_tag.tag) != br_tag.tag ) begin
                            flush_ptr = tail_ptr - unsigned'(Q_INDEX'(i));
                            break;
                        end
                    end else begin
                        if ((entries[flush_ptr[Q_INDEX-1:0]].br_tag.tag & br_tag.tag) != entries[flush_ptr[Q_INDEX-1:0]].br_tag.tag) begin
                            flush_ptr = tail_ptr - unsigned'(Q_INDEX'(i));
                            break;
                        end 
                    end 
                    if (flush_ptr == head_ptr) begin
                        flush_ptr = head_ptr;
                        break;
                    end 
                end 
            end 
        end 

        if (store_commit) begin
            target_addr_imm = entries[commit_rdy_ptr[Q_INDEX-1:0]].rs1_data + entries[commit_rdy_ptr[Q_INDEX-1:0]].imm_value;
            shift_bits_imm = target_addr_imm[1:0];

            unique case (entries[commit_rdy_ptr[Q_INDEX-1:0]].funct3)
                sb: wmask_imm = 4'b0001 << shift_bits_imm;
                sh: begin
                    wmask_imm = 4'b0011 << shift_bits_imm;
                end
                sw: begin
                    wmask_imm = 4'b1111;
                end
                default: wmask_imm = 'x;
            endcase

            unique case (entries[commit_rdy_ptr[Q_INDEX-1:0]].funct3)
                sb: data_imm[8 *shift_bits_imm[1:0] +: 8 ] = entries[commit_rdy_ptr[Q_INDEX-1:0]].rs2_data[7 :0];
                sh: data_imm[16*shift_bits_imm[1]   +: 16] = entries[commit_rdy_ptr[Q_INDEX-1:0]].rs2_data[15:0];
                sw: data_imm = entries[commit_rdy_ptr[Q_INDEX-1:0]].rs2_data;
                default: data_imm = 'x;
            endcase
        end

    end 

endmodule
