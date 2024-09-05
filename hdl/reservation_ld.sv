module ResStation_ld_m
import rv32i_types::*; 
#(  parameter size = 4,
    parameter ROB_WIDTH = 3
)(
    input logic clk,
    input logic rst,

    input logic flush, 
    input branch_tag_t flush_tag,

    input logic st_committed,
    
    input ResEntryLd_reg_t entry_in,
    input logic read_en,
    output logic rs_ready,

    input CDB_output_t CDB_value,

    input  logic FU_running,
    output logic issue,
    output ResEntryLd_reg_t entry_out
);

ResEntryLd_reg_t entries[size];
logic [size-1 : 0] entry_empty;
logic [size-1 : 0] entry_ready;
logic [size-1 : 0] issue_idx;

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < size; i++) begin
            entries[i] <= '0;
            entry_empty[i] <= '1;
        end
        
    end else begin
        if (flush) begin
            for (int i = 0; i < size; i++) begin
                if (entries[i].br_tag.sign == flush_tag.sign) begin
                    if ((entries[i].br_tag.tag & flush_tag.tag) == flush_tag.tag) begin
                        entry_empty[i] <= 1'b1;
                    end
                end else if (entries[i].br_tag.sign != flush_tag.sign) begin
                    if ((entries[i].br_tag.tag & flush_tag.tag) == entries[i].br_tag.tag) begin
                        entry_empty[i] <= 1'b1;
                    end 
                end

                if (!(entry_empty[i] || (unsigned'(size'(i)) == issue_idx)) && (!entries[i].rs1_ready && entries[i].rs1_data[ROB_WIDTH-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid)) begin
                    entries[i].rs1_data <= CDB_value.rd_v;
                    entries[i].rs1_ready <= 1'b1;
                end
                if (!(entry_empty[i] || (unsigned'(size'(i)) == issue_idx)) && st_committed) begin
                    entries[i].st_offset <= entries[i].st_offset >> 1;
                end 
            end 
        end else if (read_en) begin
            for (int i = 0; i < size; i++) begin
                /* entry_empty updated at clock edge, meaning entry issued last cycle wouldn't be 
                   marked as empty when new entry comes in. Thus the i == issue_idx check */
                if  (unsigned'(size'(i)) == issue_idx) begin
                    entries[i] <= entry_in;
                    entry_empty[i] <= 1'b0;
                    break;
                end else if (entry_empty[i])begin
                    entries[i] <= entry_in;
                    entry_empty[i] <= 1'b0;
                    if (issue_idx != unsigned'(size'(signed'(1'b1))))
                        entry_empty[issue_idx] <= 1'b1;
                    break;
                end
            end 
        end else begin
            if (issue_idx != unsigned'(size'(signed'(1'b1)))) begin
                entry_empty[issue_idx] <= 1'b1;
            end
        end 

        if (!flush) begin
            for (int i = 0; i < size; i++) begin
                if (!(entry_empty[i] || (unsigned'(size'(i)) == issue_idx)) && (!entries[i].rs1_ready && entries[i].rs1_data[ROB_WIDTH-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid)) begin
                    entries[i].rs1_data <= CDB_value.rd_v;
                    entries[i].rs1_ready <= 1'b1;
                end
                if (!(entry_empty[i] || (unsigned'(size'(i)) == issue_idx)) && st_committed) begin
                    entries[i].st_offset <= entries[i].st_offset >> 1;
                end 
            end
        end 
    end 

    
end

always_comb begin
    issue_idx = unsigned'(size'(signed'(1'b1)));
    entry_out = 'x;

    for (int i = 0; i < size; i++) begin
        entry_ready[i] = !entry_empty[i] && (entries[i].rs1_ready || (entries[i].rs1_data[ROB_WIDTH-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid)) && (entries[i].st_offset == 0);
    end

    issue = ((entry_ready & unsigned'(size'(signed'(1'b1)))) != 0) && !FU_running;
    
    rs_ready = 1'b0;
    for (int i = 0; i < size; i++) begin
        if (entry_empty[i] || (issue_idx != unsigned'(size'(signed'(1'b1))))) begin
            rs_ready = 1'b1;
        end 
    end

    

    if (issue) begin
        for (int i = 0; i < size; i++) begin
            if (entry_ready[i]) begin
                entry_out = entries[i];
                if ((!entries[i].rs1_ready) && (entries[i].rs1_data[ROB_WIDTH-1:0] == CDB_value.dest_ROB && CDB_value.commit_valid)) begin
                    entry_out.rs1_data = CDB_value.rd_v;
                end 
                issue_idx = unsigned'(size'(i));
                break;
            end 
        end 
    end 
    

end 

endmodule : ResStation_ld_m
