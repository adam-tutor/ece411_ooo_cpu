
module plrufile#(
    parameter NUM_SET = 16,
    parameter SET_IDX = 4
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           regf_we,
    input   logic   [2:0]   plru_dv,
    input   logic   [SET_IDX-1:0]   plru_sr, plru_dr,
    input   logic   [2:0]   plru_mask,
    output  logic   [2:0]   plru_sv
);

    logic   [2:0]  data [NUM_SET];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_SET; i++) begin
                data[i] <= 3'b000;
            end
        end else if (regf_we) begin
            if(plru_mask[0]) data[plru_dr][0] <= plru_dv[0];
            if(plru_mask[1]) data[plru_dr][1] <= plru_dv[1];
            if(plru_mask[2]) data[plru_dr][2] <= plru_dv[2];
        end
    end

    always_comb begin
        if (rst) begin
            plru_sv = 3'b000;
        end 
        else begin
            plru_sv = data[plru_sr];
        end
    end

endmodule : plrufile
