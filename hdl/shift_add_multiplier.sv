module shift_add_multiplier
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

    enum int unsigned {IDLE, SHIFT, ADD, DONE} curr_state, next_state;
    localparam int OP_WIDTH_LOG = $clog2(OPERAND_WIDTH);
    logic [OP_WIDTH_LOG-1:0] counter;
    logic [OPERAND_WIDTH-1:0] b_reg;
    logic [2*OPERAND_WIDTH-1:0] accumulator, a_reg; // a_reg needs to be 2 times wide since it is shifted left
    logic neg_result;
    branch_tag_t br_tag_reg;

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
            IDLE:    next_state = start ? ADD : IDLE;
            ADD:     next_state = SHIFT;
            SHIFT:   next_state = (unsigned'(counter) == unsigned'((OP_WIDTH_LOG)'(OPERAND_WIDTH-1))) ? DONE : ADD;
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
        end

        else
        begin
            if (flush_valid) begin
                curr_state <= IDLE;
            end else begin
                curr_state <= next_state;
                unique case (curr_state)
                    IDLE:
                    begin
                        if (start && !flush)
                        begin
                            accumulator <= '0;
                            unique case (mul_type)
                                `UNSIGNED_UNSIGNED_MUL:
                                begin
                                    neg_result <= '0;   // Not used in case of unsigned mul, but just cuz . . .
                                    a_reg <= {{OPERAND_WIDTH{1'b0}}, a};
                                    b_reg <= b;
                                end
                                `SIGNED_SIGNED_MUL:
                                begin
                                    // A -*+ or +*- results in a negative number unless the "positive" number is 0
                                    neg_result <= (a[OPERAND_WIDTH-1] ^ b[OPERAND_WIDTH-1]) && ((a != '0) && (b != '0));
                                    // If operands negative, make positive
                                    a_reg <= (a[OPERAND_WIDTH-1]) ? {OPERAND_WIDTH*{1'b0}, (~a + 1'b1)} : a;
                                    b_reg <= (b[OPERAND_WIDTH-1]) ? {(~b + 1'b1)} : b;
                                end
                                `SIGNED_UNSIGNED_MUL:
                                begin
                                    neg_result <= a[OPERAND_WIDTH-1];
                                    a_reg <= (a[OPERAND_WIDTH-1]) ? {OPERAND_WIDTH*{1'b0}, (~a + 1'b1)} : a;
                                    b_reg <= b;
                                end
                                default:;
                            endcase
                            br_tag_reg <= br_tag;
                        end
                    end
                    ADD: if (b_reg[0]) accumulator <= accumulator + a_reg;
                    SHIFT:
                    begin
                        a_reg <= a_reg<<1;
                        b_reg <= b_reg>>1;
                        counter <= counter + 1'b1;
                    end
                    DONE: counter <= '0;
                    default: ;
                endcase
            end 
        end
    end

endmodule
