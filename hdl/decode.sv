module idecode_m
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           flush,

    input   logic           valid,
    input   logic   [31:0]  in,
    input   logic   [31:0]  pc,   
    input   logic           stall,

    output decoded_inst_t decode_out,
    
    output rvfi_signal_t rvfi_out   
);

    logic   [31:0]  inst;

    logic   [2:0]   funct3;
    logic   [6:0]   funct7;

    logic   rs1_data_ready, rs2_data_ready, rd_s_valid;
    logic   [31:0]  prev_pc;
    
    logic   [31:0]  i_imm;
    logic   [31:0]  s_imm;
    logic   [31:0]  b_imm;
    logic   [31:0]  u_imm;
    logic   [31:0]  j_imm;

    logic   [4:0]   rs1_s, rs2_s, rd_s;
    logic   [6:0]   opcode;
    logic           inst_valid;

    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];
    assign i_imm  = {{21{inst[31]}}, inst[30:20]};
    assign s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imm  = {inst[31:12], 12'h000};
    assign j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    assign rs1_s  = (!rs1_data_ready) ? inst[19:15] : 5'b0;
    assign rs2_s  = (!rs2_data_ready) ? inst[24:20] : 5'b0;
    assign rd_s   = rd_s_valid ? inst[11:7] : 5'b0;

    always_ff @(posedge clk) begin
        
        if (rst || flush) begin
            inst <= '0;
            prev_pc <= '0;
            inst_valid <= '0;
        end else if (stall) begin
            inst <= inst;
            prev_pc <= prev_pc;
            inst_valid <= inst_valid;
        end else if (!valid) begin
            inst <= 32'b0;
            prev_pc <= pc;
            inst_valid <= '0;
        end else begin
            inst <= in;
            prev_pc <= pc;
            inst_valid <= valid;
        end
    end

    assign decode_out.data_a_is_imm = rs1_data_ready;
    assign decode_out.data_b_is_imm = rs2_data_ready;

    always_comb begin
        rs1_data_ready = 1'b1;
        rs2_data_ready = 1'b1;
        
        rd_s_valid = 1'b1;

        decode_out.operand_a = 32'bx;
        decode_out.operand_b = 32'bx;
        decode_out.current_pc = 32'bx;
        decode_out.alu_opcode = 3'b0;
    
        decode_out.mem_op = 2'b00;

        decode_out.imm_val = 32'bx;
        decode_out.alu_rd_type = 2'b00;

        decode_out.function_type = misc;
        decode_out.mult_type = 'x;
        decode_out.upper = 'x;

        decode_out.div_op = 'x;

        unique case (opcode)
            op_b_lui   : begin
                rs1_data_ready = 1'b1;
                rs2_data_ready = 1'b1;

                decode_out.operand_a = u_imm;
                decode_out.operand_b = 32'h0000;

                decode_out.alu_rd_type = 2'b11;

                decode_out.alu_opcode = alu_add;
                decode_out.function_type = alu_op;
            end
            op_b_auipc : begin
                rs1_data_ready = 1'b1;
                rs2_data_ready = 1'b1;

                decode_out.operand_a = u_imm;
                decode_out.operand_b = prev_pc;

                decode_out.alu_rd_type = 2'b11;

                decode_out.alu_opcode = alu_add;
                decode_out.function_type = alu_op;
            end
            op_b_jal   : begin
                decode_out.function_type = jmp_op;

                rs1_data_ready = 1'b1;
                rs2_data_ready = 1'b1;

                decode_out.operand_a = prev_pc;
                decode_out.operand_b = j_imm;

                decode_out.current_pc = prev_pc;
                decode_out.imm_val = 32'd4;

            end
            op_b_jalr  : begin
                decode_out.function_type = jmp_op;

                rs1_data_ready = 1'b0;
                rs2_data_ready = 1'b1;

                decode_out.operand_a = 'x;
                decode_out.operand_b = i_imm;

                decode_out.current_pc = prev_pc;
                decode_out.imm_val = 32'd4;

            end
            op_b_br    : begin
                decode_out.function_type = brn_op;

                rs1_data_ready = 1'b0;
                rs2_data_ready = 1'b0;
                rd_s_valid = 1'b0;

                decode_out.operand_a = 'x;
                decode_out.operand_b = 'x;

                decode_out.current_pc = prev_pc;
                decode_out.imm_val = b_imm;

                decode_out.alu_opcode = funct3;
            end
            op_b_load  : begin
                rs1_data_ready = 1'b0;

                decode_out.mem_op = 2'b10;
                decode_out.imm_val = i_imm;
            end
            op_b_store : begin
                rs1_data_ready = 1'b0;
                rs2_data_ready = 1'b0;
                rd_s_valid = 1'b0;

                decode_out.mem_op = 2'b01;
                decode_out.imm_val = s_imm;
            end
            op_b_imm   : begin
                rs1_data_ready = 1'b0;
                rs2_data_ready = 1'b1;
                decode_out.operand_b = i_imm;

                decode_out.function_type = alu_op;

                if (funct3 == slt) begin
                    decode_out.alu_opcode = blt;
                    decode_out.alu_rd_type = 2'b10;
                end 
                else if (funct3 == sltu) begin
                    decode_out.alu_opcode = bltu;
                    decode_out.alu_rd_type = 2'b10;
                end 
                else if (funct3 == sr) begin
                    if (funct7[5]) begin
                        decode_out.alu_opcode = alu_sra;
                    end else begin
                        decode_out.alu_opcode = alu_srl;
                    end 
                    decode_out.alu_rd_type = 2'b11;
                end 
                else begin
                    decode_out.alu_opcode = funct3;
                    decode_out.alu_rd_type = 2'b11;
                end 
            end
            op_b_reg   : begin
                rs1_data_ready = 1'b0;
                rs2_data_ready = 1'b0;
                decode_out.operand_a = 'x;
                decode_out.operand_b = 'x;
                decode_out.function_type = alu_op;

                if(funct7 == multiply) begin 
                    decode_out.function_type = mul_op;
                    if (funct3 == funct3_mul) begin
                        decode_out.mult_type = 2'b00;
                        decode_out.upper = 1'b0;
                    end else if (funct3 == funct3_mulh) begin
                        decode_out.mult_type = 2'b00;
                        decode_out.upper = 1'b1;
                    end else if (funct3 == funct3_mulhsu) begin
                        decode_out.mult_type = 2'b01;
                        decode_out.upper = 1'b1;
                    end else if (funct3 == funct3_mulhu) begin
                        decode_out.mult_type = 2'b10;
                        decode_out.upper = 1'b1;
                    end else if (funct3 == funct3_div) begin
                        decode_out.function_type = div_op;
                        decode_out.div_op = division_op;
                    end else if (funct3 == funct3_divu) begin
                        decode_out.function_type = div_op;
                        decode_out.div_op = division_op;
                    end else if (funct3 == funct3_rem) begin
                        decode_out.function_type = div_op;
                        decode_out.div_op = remainder_op;
                    end else if (funct3 == funct3_remu) begin
                        decode_out.function_type = div_op;
                        decode_out.div_op = remainder_op;
                    end else begin
                        decode_out.mult_type = 2'b00;
                        decode_out.upper = 1'b0;
                        decode_out.div_op = 1'b0;
                    end 
                end
                else begin
                    if (funct3 == slt) begin
                        decode_out.alu_opcode = blt;
                        decode_out.alu_rd_type = 2'b10;
                    end else if (funct3 == sltu) begin
                        decode_out.alu_opcode = bltu;
                        decode_out.alu_rd_type = 2'b10;
                    end else if (funct3 == sr) begin
                        if (funct7[5]) begin
                            decode_out.alu_opcode = alu_sra;
                        end else begin
                            decode_out.alu_opcode = alu_srl;
                        end 
                        decode_out.alu_rd_type = 2'b11;
                    end else if (funct3 == add) begin
                        if (funct7[5]) begin
                            decode_out.alu_opcode = alu_sub;
                        end else begin
                            decode_out.alu_opcode = alu_add;
                        end
                        decode_out.alu_rd_type = 2'b11;
                    end else begin
                        decode_out.alu_opcode = funct3;
                        decode_out.alu_rd_type = 2'b11;
                    end 
                end
            end
            default  : begin 
                rs1_data_ready = 1'b0;
                rs2_data_ready = 1'b0;
                rd_s_valid = 1'b0;
            end
        endcase

        rvfi_out = 'x;

        if (inst_valid && !stall) begin
            rvfi_out.inst = inst;
            rvfi_out.valid = inst_valid;
            rvfi_out.rs1_addr = rs1_s;
            rvfi_out.rs2_addr = rs2_s;
            rvfi_out.rd_addr = rd_s;
            rvfi_out.pc_rdata = prev_pc;
            rvfi_out.pc_wdata = prev_pc + 4'd4;
            rvfi_out.mem_addr = 'x;
            rvfi_out.mem_rmask = '0;
            rvfi_out.mem_wmask = '0;
            rvfi_out.mem_rdata = 'x;
            rvfi_out.mem_wdata = 'x;
        end else begin
            rvfi_out = 'x;
            rvfi_out.valid = 1'b0;
        end
    end
    assign decode_out.funct3 = funct3;
    assign decode_out.funct7 = funct7;

endmodule : idecode_m
