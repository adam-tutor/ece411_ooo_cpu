module dadda_multiplier_32
#(
    parameter int OPERAND_WIDTH = 32
)
(
    input clk, rst,
    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[2*OPERAND_WIDTH-1:0] p
);

logic [2*OPERAND_WIDTH-1:0] partial_products [OPERAND_WIDTH];
logic [31:0] m1, m1_r;
logic [47:0] m2, m2_r, m3, m3_r, m4, m4_r;
logic [15:0] a_upper, a_lower, b_upper, b_lower;
logic [31:0] multiplier_result1, multiplier_result2, multiplier_result3, multiplier_result4, multiplier_result1_r, multiplier_result2_r, multiplier_result3_r, multiplier_result4_r;  
always_comb begin
    a_upper = a[31:16];
    a_lower = a[15:0];
    b_upper = b[31:16];
    b_lower = b[15:0];
end

dadda_multiplier_16 #(.OPERAND_WIDTH(16)) four_16(.clk(clk),.rst(rst),.a(a_lower), .b(b_lower), .p(multiplier_result1));
dadda_multiplier_16 #(.OPERAND_WIDTH(16)) two_16(.clk(clk),.rst(rst),.a(a_upper), .b(b_lower), .p(multiplier_result2));
dadda_multiplier_16 #(.OPERAND_WIDTH(16)) three_16(.clk(clk),.rst(rst),.a(a_lower), .b(b_upper), .p(multiplier_result3));
dadda_multiplier_16 #(.OPERAND_WIDTH(16)) one_16(.clk(clk),.rst(rst),.a(a_upper), .b(b_upper), .p(multiplier_result4));

always_ff @(posedge clk) begin 
    if(rst) begin
        multiplier_result1_r <= '0;
        multiplier_result2_r <= '0;
        multiplier_result3_r <= '0;
        multiplier_result4_r <= '0;
        m1_r <= '0;
        m2_r <= '0;
        m3_r <= '0;
        m4_r <= '0;
    end
    else begin
        multiplier_result1_r <= multiplier_result1;
        multiplier_result2_r <= multiplier_result2;
        multiplier_result3_r <= multiplier_result3;
        multiplier_result4_r <= multiplier_result4;
        m1_r <= m1;
        m2_r <= m2;
        m3_r <= m3;
        m4_r <= m4;
    end
end


assign m1 = multiplier_result1_r;
assign m2 = {16'b0,(multiplier_result2_r + {16'b0,m1_r[31:16]})};
assign m3 = m2_r + {16'b0, multiplier_result3_r};
assign m4 = m3_r + {multiplier_result4_r,16'b0};
assign p[15:0] = m1_r[15:0];
assign p[63:16] = m4_r;

endmodule


module dadda_multiplier_16
#(
    parameter int OPERAND_WIDTH = 16
)
(
    input clk, rst,
    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[2*OPERAND_WIDTH-1:0] p
);

logic [2*OPERAND_WIDTH-1:0] partial_products [OPERAND_WIDTH];
logic [15:0] m1, m1_r;
logic [23:0] m2, m2_r, m3, m3_r, m4, m4_r;
logic [7:0] a_upper, a_lower, b_upper, b_lower;
logic [15:0] multiplier_result1, multiplier_result2, multiplier_result3, multiplier_result4;
logic [15:0] multiplier_result1_r, multiplier_result2_r, multiplier_result3_r, multiplier_result4_r; 
always_comb begin
    a_upper = a[15:8];
    a_lower = a[7:0];
    b_upper = b[15:8];
    b_lower = b[7:0];
end

dadda_multiplier_eight #(.OPERAND_WIDTH(8)) four(.clk(clk),.rst(rst), .a(a_lower), .b(b_lower), .p(multiplier_result1));
dadda_multiplier_eight #(.OPERAND_WIDTH(8)) two(.clk(clk),.rst(rst), .a(a_upper), .b(b_lower), .p(multiplier_result2));
dadda_multiplier_eight #(.OPERAND_WIDTH(8)) three(.clk(clk),.rst(rst), .a(a_lower), .b(b_upper), .p(multiplier_result3));
dadda_multiplier_eight #(.OPERAND_WIDTH(8)) one(.clk(clk),.rst(rst), .a(a_upper), .b(b_upper), .p(multiplier_result4));

always_ff @(posedge clk) begin 
    if(rst) begin
        multiplier_result1_r <= '0;
        multiplier_result2_r <= '0;
        multiplier_result3_r <= '0;
        multiplier_result4_r <= '0;
        m1_r <= '0;
        m2_r <= '0;
        m3_r <= '0;
        m4_r <= '0;
    end
    else begin
        multiplier_result1_r <= multiplier_result1;
        multiplier_result2_r <= multiplier_result2;
        multiplier_result3_r <= multiplier_result3;
        multiplier_result4_r <= multiplier_result4;
        m1_r <= m1;
        m2_r <= m2;
        m3_r <= m3;
        m4_r <= m4;
    end
end

assign m1 = multiplier_result1_r;
assign m2 = {8'b0,(multiplier_result2_r + {8'b0,m1_r[15:8]})};
assign m3 = m2_r + {8'b0, multiplier_result3_r};
assign m4 = m3_r + {multiplier_result4_r,8'b0};
assign p[7:0] = m1_r[7:0];
assign p[31:8] = m4_r;

// assign p[7:0] = multiplier_result1_r[7:0];
// assign p[31:8] = {8'b0,(multiplier_result2_r + {8'b0,multiplier_result1_r[15:8]})} + {multiplier_result4_r,8'b0} + {8'b0, multiplier_result3_r};

endmodule


module dadda_multiplier_eight
#(
    parameter int OPERAND_WIDTH = 8
)
(
    input clk, rst,
    input logic[OPERAND_WIDTH-1:0] a,
    input logic[OPERAND_WIDTH-1:0] b,
    output logic[2*OPERAND_WIDTH-1:0] p
);
logic [2*OPERAND_WIDTH-1:0] partial_products [OPERAND_WIDTH];
always_comb begin
    for(int i = 0; i < OPERAND_WIDTH; i++) begin
        partial_products[i] = ({8'b0,{a & {8{b[i]}}}}) << i;
    end
end

logic s4_c[6], s4_s[6], s3_c[14], s3_s[14], s2_c[10], s2_s[10], s1_c[12], s1_s[12], c[14];
logic s4_c_r[6], s4_s_r[6], s3_c_r[14], s3_s_r[14], s2_c_r[10], s2_s_r[10], s1_c_r[12], s1_s_r[12];

always_ff @(posedge clk) begin
    for(int i = 0; i < 6; i++) begin
        if(rst) begin
            s4_c_r[i] <= '0;
            s4_s_r[i] <= '0;
        end
        else begin
            s4_c_r[i] <= s4_c[i];
            s4_s_r[i] <= s4_s[i];
        end
    end
    for(int i = 0; i < 14; i++) begin
        if(rst) begin
            s3_c_r[i] <= '0;
            s3_s_r[i] <= '0;
        end
        else begin
            s3_c_r[i] <= s3_c[i];
            s3_s_r[i] <= s3_s[i];
        end
    end
    for(int i = 0; i < 10; i++) begin
        if(rst) begin
            s2_c_r[i] <= '0;
            s2_s_r[i] <= '0;
        end
        else begin
            s2_c_r[i] <= s2_c[i];
            s2_s_r[i] <= s2_s[i];
        end
    end
    for(int i = 0; i < 12; i++) begin
        if(rst) begin
            s1_c_r[i] <= '0;
            s1_s_r[i] <= '0;
        end
        else begin
            s1_c_r[i] <= s1_c[i];
            s1_s_r[i] <= s1_s[i];
        end
    end
end

//Stage 4
half_adder s4_h1(.a_in(partial_products[0][6]), .b_in(partial_products[1][6]), .sum(s4_s[0]), .c_out(s4_c[0]));
full_adder s4_f1(.a_in(partial_products[0][7]), .b_in(partial_products[1][7]), .c_in(partial_products[2][7]), .sum(s4_s[1]), .c_out(s4_c[1]));
half_adder s4_h2(.a_in(partial_products[3][7]), .b_in(partial_products[4][7]), .sum(s4_s[2]), .c_out(s4_c[2]));
full_adder s4_f2(.a_in(partial_products[1][8]), .b_in(partial_products[2][8]), .c_in(partial_products[3][8]), .sum(s4_s[3]), .c_out(s4_c[3]));
half_adder s4_h3(.a_in(partial_products[4][8]), .b_in(partial_products[5][8]), .sum(s4_s[4]), .c_out(s4_c[4]));
full_adder s4_f4(.a_in(partial_products[2][9]), .b_in(partial_products[3][9]), .c_in(partial_products[4][9]), .sum(s4_s[5]), .c_out(s4_c[5]));

//Stage 3

half_adder s3_1(.a_in(partial_products[0][4]), .b_in(partial_products[1][4]), .sum(s3_s[0]), .c_out(s3_c[0]));
full_adder s3_2(.a_in(partial_products[0][5]), .b_in(partial_products[1][5]), .c_in(partial_products[2][5]), .sum(s3_s[1]), .c_out(s3_c[1]));
half_adder s3_3(.a_in(partial_products[3][5]), .b_in(partial_products[4][5]), .sum(s3_s[2]), .c_out(s3_c[2]));
full_adder s3_4(.a_in(s4_s_r[0]), .b_in(partial_products[2][6]), .c_in(partial_products[3][6]), .sum(s3_s[3]), .c_out(s3_c[3]));
full_adder s3_5(.a_in(partial_products[4][6]), .b_in(partial_products[5][6]), .c_in(partial_products[6][6]), .sum(s3_s[4]), .c_out(s3_c[4]));
full_adder s3_6(.a_in(s4_s_r[1]), .b_in(s4_s_r[2]), .c_in(partial_products[5][7]), .sum(s3_s[5]), .c_out(s3_c[5]));
full_adder s3_7(.a_in(partial_products[6][7]), .b_in(partial_products[7][7]), .c_in(s4_c_r[0]), .sum(s3_s[6]), .c_out(s3_c[6]));
full_adder s3_8(.a_in(s4_s_r[3]), .b_in(s4_s_r[4]), .c_in(partial_products[6][8]), .sum(s3_s[7]), .c_out(s3_c[7]));
full_adder s3_9(.a_in(partial_products[7][8]), .b_in(s4_c_r[1]), .c_in(s4_c_r[2]), .sum(s3_s[8]), .c_out(s3_c[8]));
full_adder s3_10(.a_in(s4_s_r[5]), .b_in(partial_products[5][9]), .c_in(partial_products[6][9]), .sum(s3_s[9]), .c_out(s3_c[9]));
full_adder s3_11(.a_in(partial_products[7][9]), .b_in(s4_c_r[3]), .c_in(s4_c_r[4]), .sum(s3_s[10]), .c_out(s3_c[10]));
full_adder s3_12(.a_in(partial_products[3][10]), .b_in(partial_products[4][10]), .c_in(partial_products[5][10]), .sum(s3_s[11]), .c_out(s3_c[11]));
full_adder s3_13(.a_in(partial_products[6][10]), .b_in(partial_products[7][10]), .c_in(s4_c_r[5]), .sum(s3_s[12]), .c_out(s3_c[12]));
full_adder s3_14(.a_in(partial_products[4][11]), .b_in(partial_products[5][11]), .c_in(partial_products[6][11]), .sum(s3_s[13]), .c_out(s3_c[13]));

//Stage 2

half_adder s2_1(.a_in(partial_products[0][3]), .b_in(partial_products[1][3]), .sum(s2_s[0]), .c_out(s2_c[0]));
full_adder s2_2(.a_in(s3_s_r[0]), .b_in(partial_products[2][4]), .c_in(partial_products[3][4]), .sum(s2_s[1]), .c_out(s2_c[1]));
full_adder s2_3(.a_in(s3_s_r[1]), .b_in(s3_s_r[2]), .c_in(partial_products[5][5]), .sum(s2_s[2]), .c_out(s2_c[2]));
full_adder s2_4(.a_in(s3_s_r[3]), .b_in(s3_s_r[4]), .c_in(s3_c_r[1]), .sum(s2_s[3]), .c_out(s2_c[3]));
full_adder s2_5(.a_in(s3_s_r[5]), .b_in(s3_s_r[6]), .c_in(s3_c_r[3]), .sum(s2_s[4]), .c_out(s2_c[4]));
full_adder s2_6(.a_in(s3_s_r[7]), .b_in(s3_s_r[8]), .c_in(s3_c_r[5]), .sum(s2_s[5]), .c_out(s2_c[5]));
full_adder s2_7(.a_in(s3_s_r[9]), .b_in(s3_s_r[10]), .c_in(s3_c_r[7]), .sum(s2_s[6]), .c_out(s2_c[6]));
full_adder s2_8(.a_in(s3_s_r[11]), .b_in(s3_s_r[12]), .c_in(s3_c_r[9]), .sum(s2_s[7]), .c_out(s2_c[7]));
full_adder s2_9(.a_in(s3_s_r[13]), .b_in(partial_products[7][11]), .c_in(s3_c_r[11]), .sum(s2_s[8]), .c_out(s2_c[8]));
full_adder s2_10(.a_in(partial_products[5][12]), .b_in(partial_products[6][12]), .c_in(partial_products[7][12]), .sum(s2_s[9]), .c_out(s2_c[9]));

//Stage 1

half_adder s1_1(.a_in(partial_products[0][2]), .b_in(partial_products[1][2]), .sum(s1_s[0]), .c_out(s1_c[0]));
full_adder s1_2(.a_in(s2_s_r[0]), .b_in(partial_products[2][3]), .c_in(partial_products[3][3]), .sum(s1_s[1]), .c_out(s1_c[1]));
full_adder s1_3(.a_in(s2_s_r[1]), .b_in(partial_products[4][4]), .c_in(s2_c_r[0]), .sum(s1_s[2]), .c_out(s1_c[2]));
full_adder s1_4(.a_in(s2_s_r[2]), .b_in(s3_c_r[0]), .c_in(s2_c_r[1]), .sum(s1_s[3]), .c_out(s1_c[3]));
full_adder s1_5(.a_in(s2_s_r[3]), .b_in(s3_c_r[2]), .c_in(s2_c_r[2]), .sum(s1_s[4]), .c_out(s1_c[4]));
full_adder s1_6(.a_in(s2_s_r[4]), .b_in(s3_c_r[4]), .c_in(s2_c_r[3]), .sum(s1_s[5]), .c_out(s1_c[5]));
full_adder s1_7(.a_in(s2_s_r[5]), .b_in(s3_c_r[6]), .c_in(s2_c_r[4]), .sum(s1_s[6]), .c_out(s1_c[6]));
full_adder s1_8(.a_in(s2_s_r[6]), .b_in(s3_c_r[8]), .c_in(s2_c_r[5]), .sum(s1_s[7]), .c_out(s1_c[7]));
full_adder s1_9(.a_in(s2_s_r[7]), .b_in(s3_c_r[10]), .c_in(s2_c_r[6]), .sum(s1_s[8]), .c_out(s1_c[8]));
full_adder s1_10(.a_in(s2_s_r[8]), .b_in(s3_c_r[12]), .c_in(s2_c_r[7]), .sum(s1_s[9]), .c_out(s1_c[9]));
full_adder s1_11(.a_in(s2_s_r[9]), .b_in(s3_c_r[13]), .c_in(s2_c_r[8]), .sum(s1_s[10]), .c_out(s1_c[10]));
full_adder s1_12(.a_in(partial_products[6][13]), .b_in(partial_products[7][13]), .c_in(s2_c_r[9]), .sum(s1_s[11]), .c_out(s1_c[11]));

//Final Addition
assign p[0] = partial_products[0][0];
half_adder final_1(.a_in(partial_products[0][1]), .b_in(partial_products[1][1]), .sum(p[1]), .c_out(c[0]));
full_adder final_2(.a_in(s1_s_r[0]), .b_in(partial_products[2][2]), .c_in(c[0]), .sum(p[2]), .c_out(c[1]));
full_adder final_3(.a_in(s1_s_r[1]), .b_in(s1_c_r[0]), .c_in(c[1]), .sum(p[3]), .c_out(c[2]));
full_adder final_4(.a_in(s1_s_r[2]), .b_in(s1_c_r[1]), .c_in(c[2]), .sum(p[4]), .c_out(c[3]));
full_adder final_5(.a_in(s1_s_r[3]), .b_in(s1_c_r[2]), .c_in(c[3]), .sum(p[5]), .c_out(c[4]));
full_adder final_6(.a_in(s1_s_r[4]), .b_in(s1_c_r[3]), .c_in(c[4]), .sum(p[6]), .c_out(c[5]));
full_adder final_7(.a_in(s1_s_r[5]), .b_in(s1_c_r[4]), .c_in(c[5]), .sum(p[7]), .c_out(c[6]));
full_adder final_8(.a_in(s1_s_r[6]), .b_in(s1_c_r[5]), .c_in(c[6]), .sum(p[8]), .c_out(c[7]));
full_adder final_9(.a_in(s1_s_r[7]), .b_in(s1_c_r[6]), .c_in(c[7]), .sum(p[9]), .c_out(c[8]));
full_adder final_10(.a_in(s1_s_r[8]), .b_in(s1_c_r[7]), .c_in(c[8]), .sum(p[10]), .c_out(c[9]));
full_adder final_11(.a_in(s1_s_r[9]), .b_in(s1_c_r[8]), .c_in(c[9]), .sum(p[11]), .c_out(c[10]));
full_adder final_12(.a_in(s1_s_r[10]), .b_in(s1_c_r[9]), .c_in(c[10]), .sum(p[12]), .c_out(c[11]));
full_adder final_13(.a_in(s1_s_r[11]), .b_in(s1_c_r[10]), .c_in(c[11]), .sum(p[13]), .c_out(c[12]));
full_adder final_14(.a_in(partial_products[7][14]), .b_in(s1_c_r[11]), .c_in(c[12]), .sum(p[14]), .c_out(p[15]));

endmodule