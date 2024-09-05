module regfile
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           flush, 
    input   logic           branch_dispatched,

    input   logic           dispatch_enqueue,
    input   ROBinfo_t       rob_info,

    input   logic           ROB_commit,
    input   RegFile_t       rd_v,

    input   logic   [4:0]   rs1_s, rs2_s, rd_s, rd_dis,

    output  RegFile_t       rs1_v, rs2_v,

    input   logic   [4:0]   rs1_s_rvfi, rs2_s_rvfi,

    output  RegFile_t       rs1_v_rvfi, rs2_v_rvfi
);

    RegFile_t  data [32];
    RegState_t state_copy [32];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                data[i] <= '0;
            end
        end else begin
            if (flush) begin
                for (int i = 0; i < 32; i++) begin
                    if (ROB_commit && unsigned'(5'(i)) == rd_s && unsigned'(5'(i)) != 5'b0) begin
                        data[rd_s].ROB_idx <= state_copy[rd_s].ROB_idx;
                        data[rd_s].ROB_busy <= (rd_v.ROB_idx != state_copy[rd_s].ROB_idx);
                    end else begin
                        data[i].ROB_busy <= state_copy[i].ROB_busy;
                        data[i].ROB_idx <= state_copy[i].ROB_idx;
                    end 
                 end

                // ROB Case 
                if (ROB_commit) begin
                    data[rd_s].reg_value <= (rd_s != 5'd0) ? rd_v.reg_value : '0;
                end
            end else begin
                // From Dispatch Stage
                if (dispatch_enqueue) begin
                    data[rd_dis].ROB_idx <= (rd_dis != 5'd0) ? rob_info.ROB_idx : '0;
                    data[rd_dis].ROB_busy <= (rd_dis != 5'd0) ? rob_info.ROB_busy : '0;
                    data[rd_dis].ROB_br_tag <= (rd_dis != 5'b0) ? rob_info.br_tag : '0;
                end
                // ROB Case 
                if (ROB_commit) begin
                    if(rd_s != rd_dis) begin
                        if(data[rd_s].ROB_idx == rd_v.ROB_idx) begin
                            data[rd_s].reg_value <= (rd_s != 5'd0) ? rd_v.reg_value : '0;
                            data[rd_s].ROB_busy <= 1'b0;
                            data[rd_s].ROB_idx <= '0;
                        end else begin
                            data[rd_s].reg_value <= (rd_s != 5'd0) ? rd_v.reg_value : '0;
                            data[rd_s].ROB_busy <= data[rd_s].ROB_busy;
                        end
                    end else begin
                        data[rd_s].reg_value <= (rd_s != 5'd0) ? rd_v.reg_value : '0;
                    end

                    state_copy[rd_s].ROB_busy <= state_copy[rd_s].ROB_busy && (rd_v.ROB_idx != state_copy[rd_s].ROB_idx);
                end

                if (branch_dispatched) begin
                    /* When a branch/jmp instr is dispatched, make a copy of current reg state to allow mispredict recovery */
                    for (int i = 0; i < 32; i++) begin
                        if (ROB_commit && unsigned'(5'(i)) == rd_s) begin
                            state_copy[rd_s].ROB_busy <= (rd_v.ROB_idx != data[rd_s].ROB_idx); 
                            state_copy[rd_s].ROB_idx <= data[rd_s].ROB_idx;
                        end else if (rd_dis == unsigned'(5'(i)) && dispatch_enqueue) begin
                            state_copy[i].ROB_busy <= 1'b1;
                            state_copy[i].ROB_idx <= rob_info.ROB_idx;
                        end else begin
                            state_copy[i].ROB_busy <= data[i].ROB_busy;
                            state_copy[i].ROB_idx <= data[i].ROB_idx;
                        end 
                    end 
                end 
            end
        end
    end

    always_comb begin
        rs1_v = 'x;
        rs2_v = 'x;

        rs1_v.ROB_busy = (rs1_s != 5'd0) ? data[rs1_s].ROB_busy : '0;
        rs1_v.ROB_idx = (rs1_s != 5'd0) ? data[rs1_s].ROB_idx : '0;

        if((rs1_s == rd_s) && ROB_commit) begin
            rs1_v.reg_value = (rs1_s != 5'd0) ? rd_v.reg_value : '0;
        end
        else begin
            rs1_v.reg_value = (rs1_s != 5'd0) ? data[rs1_s].reg_value : '0;
        end 


        rs2_v.ROB_busy = (rs2_s != 5'd0) ? data[rs2_s].ROB_busy : '0;
        rs2_v.ROB_idx = (rs2_s != 5'd0) ? data[rs2_s].ROB_idx : '0;
        
        if((rs2_s == rd_s) && ROB_commit) begin
            rs2_v.reg_value = (rs2_s != 5'd0) ? rd_v.reg_value : '0;
        end
        else begin
            rs2_v.reg_value = (rs2_s != 5'd0) ? data[rs2_s].reg_value : '0;
        end
        
        rs1_v_rvfi = (rs1_s_rvfi != 5'd0) ? data[rs1_s_rvfi] : '0;
        rs2_v_rvfi = (rs2_s_rvfi != 5'd0) ? data[rs2_s_rvfi] : '0;
    end

endmodule : regfile

