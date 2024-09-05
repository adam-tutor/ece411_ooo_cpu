module half_adder
import rv32i_types::*;
(
    input logic a_in, b_in, //operands
  
    output logic sum,
    output logic c_out
);
    always_comb begin
        sum = a_in ^ b_in;
        c_out = a_in & b_in;
    end
endmodule

module full_adder
import rv32i_types::*;
(
    input logic a_in, b_in, c_in, //operands
  
    output logic sum,
    output logic c_out
);
    always_comb begin
        sum = a_in ^ b_in ^ c_in;
        c_out = (a_in & b_in) | (a_in & c_in) | (b_in & c_in);
    end
endmodule

