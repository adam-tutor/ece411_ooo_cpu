module dadda_multiplier
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
    input logic [1:0] mul_type,
    input logic MUL_result_taken,

    output logic busy,
    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[2*OPERAND_WIDTH-1:0] p,
    output branch_tag_t br_tag_out,
    output logic done,

    output logic flush_valid
);

    // Constants for multiplication case readability
    `define UNSIGNED_UNSIGNED_MUL 2'b00
    `define SIGNED_SIGNED_MUL     2'b01
    `define SIGNED_UNSIGNED_MUL   2'b10

    enum int unsigned {IDLE, STAGE1,STAGE2, STAGE3, STAGE4, STAGE5, STAGE6, STAGE7,STAGE8, STAGE9, STAGE10, STAGE11, STAGE12, STAGE13, STAGE14, STAGE15, DONE} curr_state, next_state;
    localparam int OP_WIDTH_LOG = $clog2(OPERAND_WIDTH);
    logic [1:0] counter;
    logic [OPERAND_WIDTH-1:0] a_reg, b_reg;
    logic [2*OPERAND_WIDTH-1:0] accumulator, p_dadda;
    logic neg_result;
    branch_tag_t br_tag_reg;

    dadda_multiplier_32 #(.OPERAND_WIDTH(32)) comb_mult
    (
    .clk(clk), .rst(rst),
    .a(a_reg),
    .b(b_reg),
    .p(p_dadda)
    );

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
            STAGE10: next_state = STAGE11;
            STAGE11: next_state = STAGE12;
            STAGE12: next_state = STAGE13;
            STAGE13: next_state = STAGE14;
            STAGE14: next_state = STAGE15;
            STAGE15: next_state = DONE;
            DONE:    next_state = !MUL_result_taken ? DONE : IDLE;
            default: next_state = curr_state;
        endcase
    end : state_transition

    always_comb
    begin : state_outputs
        br_tag_out = 'x;
        done = '0;
        p = '0;
        unique case (curr_state)
            DONE:
            begin
                done = 1'b1;
                unique case (mul_type)
                    `UNSIGNED_UNSIGNED_MUL: p = accumulator[2*OPERAND_WIDTH-1:0];
                    `SIGNED_SIGNED_MUL,
                    `SIGNED_UNSIGNED_MUL: p = neg_result ? (~accumulator[2*OPERAND_WIDTH-1-1:0])+1'b1 : accumulator;
                    default: ;
                endcase
                br_tag_out = br_tag_reg;
            end
            default: ;
        endcase
    end : state_outputs

    always_ff @ (posedge clk)
    begin
        if (rst)
        begin
            curr_state <= IDLE;
            a_reg <= '0;
            b_reg <= '0;
            accumulator <= '0;
            counter <= '0;
            neg_result <= '0;
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
                        accumulator <= '0;
                        busy <= 1'b1;
                        unique case (mul_type)
                            `UNSIGNED_UNSIGNED_MUL:
                            begin
                                neg_result <= '0;   // Not used in case of unsigned mul, but just cuz . . .
                                a_reg <= a;
                                b_reg <= b;
                            end
                            `SIGNED_SIGNED_MUL:
                            begin
                                // A -*+ or +*- results in a negative number unless the "positive" number is 0
                                neg_result <= (a[OPERAND_WIDTH-1] ^ b[OPERAND_WIDTH-1]) && ((a != '0) && (b != '0));
                                // If operands negative, make positive
                                a_reg <= (a[OPERAND_WIDTH-1]) ? {(~a + 1'b1)} : a;
                                b_reg <= (b[OPERAND_WIDTH-1]) ? {(~b + 1'b1)} : b;
                            end
                            `SIGNED_UNSIGNED_MUL:
                            begin
                                neg_result <= a[OPERAND_WIDTH-1];
                                a_reg <= (a[OPERAND_WIDTH-1]) ? {(~a + 1'b1)} : a;
                                b_reg <= b;
                            end
                            default:;
                        endcase
                        br_tag_reg <= br_tag;
                    end
                    else busy <= 1'b0;
                end
                STAGE1: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE2: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE3: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE4: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE5: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE6: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE7: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE8: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE9: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE10: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE11: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE12: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE13: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE14: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                STAGE15: 
                begin
                    counter <= counter + 1'b1;
                    accumulator <= p_dadda;
                    busy <= 1'b1;
                end
                DONE: 
                begin
                    counter <= '0;
                    if(MUL_result_taken) busy <= 1'b0;
                    else busy <= 1'b1;
                end
                default: ;
            endcase
        end
    end
    end
endmodule
