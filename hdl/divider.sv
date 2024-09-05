module divider
import rv32i_types::*;
#(
    parameter int OPERAND_WIDTH = 32
)
(
    input logic clk,
    input logic rst,
    // Start must be reset after the done flag is set before another multiplication can execute
    input logic start,
    input branch_tag_t br_tag,

    input logic flush,
    input branch_tag_t flush_tag,

    // Use this input to select what type of multiplication you are performing
    // 0 = Multiply two unsigned numbers
    // 1 = Multiply two signed numbers
    // 2 = Multiply a signed number and unsigned number
    //      a = signed
    //      b = unsigned
    input logic div_type,
    input logic DIV_result_taken,

    output logic busy,
    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[OPERAND_WIDTH-1:0] division_result,
    output branch_tag_t br_tag_out,
    output logic done,

    output logic flush_valid
);

    enum int unsigned {IDLE, STAGE1, STAGE2, STAGE3, STAGE4, STAGE5, STAGE6, STAGE7, STAGE8, STAGE9, STAGE10, STAGE11, STAGE12, STAGE13, STAGE14, STAGE15, STAGE16, DONE} curr_state, next_state;
  
    branch_tag_t br_tag_reg;

    logic hold, done_divider, divide_0, temp;
    logic [31:0] q, r;
    assign hold = 1'b0;
    assign temp = divide_0;

    DW_div_seq #(32, 32, 0, 16,
               0, 1, 1,
               0) 
        U1 (.clk(clk),   .rst_n(!rst),   .hold(hold), 
        .start(start),   .a(a),   .b(b), 
        .complete(done_divider),   .divide_by_0(divide_0), 
        .quotient(q),   .remainder(r));

    always_comb begin
        flush_valid = 1'b0;
        if (flush) begin
            if (br_tag_reg.sign == flush_tag.sign) begin
                if ((br_tag_reg.tag & flush_tag.tag) == flush_tag.tag) begin
                    flush_valid = 1'b1;
                end
            end else if (br_tag_reg.sign != flush_tag.sign) begin
                if ((br_tag_reg.tag & flush_tag.tag) == br_tag_reg.tag) begin
                    flush_valid = 1'b1;
                end 
            end
        end 
    end 

    always_comb
    begin : state_transition
        next_state = curr_state;
        unique case (curr_state)
            IDLE:    next_state = start ?  STAGE1 : IDLE;
            STAGE1:  next_state = STAGE2;
            STAGE2:  next_state = STAGE3;
            STAGE3:  next_state = STAGE4;
            STAGE4:  next_state = STAGE5;
            STAGE5:  next_state = STAGE6;
            STAGE6:  next_state = STAGE7;
            STAGE7:  next_state = STAGE8;
            STAGE8:  next_state = STAGE9;
            STAGE9:  next_state = STAGE10;
            STAGE10:  next_state = STAGE11;
            STAGE11:  next_state = STAGE12;
            STAGE12:  next_state = STAGE13;
            STAGE13:  next_state = STAGE14;
            STAGE14:  next_state = STAGE15;
            STAGE15:  next_state = STAGE16;
            STAGE16:  next_state = DONE;
            DONE:    next_state = !DIV_result_taken ? DONE : IDLE;
            default: next_state = curr_state;
        endcase
    end : state_transition

    always_comb
    begin : state_outputs
        br_tag_out = 'x;
        done = '0;
        division_result = '0;
        unique case (curr_state)
            DONE:
            begin
                done = 1'b1;
                br_tag_out = br_tag_reg;
                if(div_type == division_op) division_result = q;
                else if (div_type == remainder_op) division_result = r;
            end
            default: ;
        endcase
    end : state_outputs

    always_ff @ (posedge clk)
    begin
        if (rst)
        begin
            curr_state <= IDLE;
            br_tag_reg <= '0;
            busy <= '0;
        end
        else
        begin
            if (flush_valid) begin
                curr_state <= IDLE;
            end 
            else begin
            curr_state <= next_state;
            unique case (curr_state)
                IDLE:
                begin
                    if (start  && !flush)
                    begin
                        busy <= 1'b1;
                        br_tag_reg <= br_tag;
                    end
                    else busy <= 1'b0;
                end
                STAGE1: 
                begin
                    busy <= 1'b1;
                end
                STAGE2: 
                begin
                    busy <= 1'b1;
                end
                STAGE3: 
                begin
                    busy <= 1'b1;
                end
                STAGE4: 
                begin
                    busy <= 1'b1;
                end
                STAGE5: 
                begin
                    busy <= 1'b1;
                end
                STAGE6: 
                begin
                    busy <= 1'b1;
                end
                STAGE7: 
                begin
                    busy <= 1'b1;
                end
                STAGE8: 
                begin
                    busy <= 1'b1;
                end
                STAGE9: 
                begin
                    busy <= 1'b1;
                end
                STAGE10: 
                begin
                    busy <= 1'b1;
                end
                STAGE11: 
                begin
                    busy <= 1'b1;
                end
                STAGE12: 
                begin
                    busy <= 1'b1;
                end
                STAGE13: 
                begin
                    busy <= 1'b1;
                end
                STAGE14: 
                begin
                    busy <= 1'b1;
                end
                STAGE15: 
                begin
                    busy <= 1'b1;
                end
                STAGE16: 
                begin
                    busy <= 1'b1;
                end
                DONE: 
                begin
                    if(DIV_result_taken) busy <= 1'b0;
                    else busy <= 1'b1;
                end
                default: ;
            endcase
        end
    end
    end


endmodule
