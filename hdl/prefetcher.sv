module prefetcher
import rv32i_types::*;
(
    input clk, rst, flush,
    input   logic [31:0]   dfp_addr, //dfp addr to icache
    //input   logic [31:0]   imem_addr,
    input   logic           dfp_read, //dfp read  to icache
    output  logic [255:0]   dfp_rdata, //dfp rdata to icache
    output  logic          dfp_resp, //dfp resp to icache
    //input   logic          branch_taken,
    //input   logic           jump_taken,
    input   logic [255:0]   ibmem_rdata, //FROM ARBITER/MEM
    input   logic           ibmem_resp, //FROM ARBITER/MEM
    output  logic [31:0]    ibmem_addr, //TO ARBITER/MEM 
    output  logic           ibmem_read, //TO ARBITER/MEM
    input   logic           arbiter_idle //is the arbiter free?
);

    enum logic [1:0] {ICACHE, PREFETCH, IDLE} state, next_state;

    logic prefetch_en, prefetch_en_reg;
    logic [31:0] prev_cl_addr, prev_pf_addr, pf_addr;

    logic [255:0] ibmem_rdata_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            prefetch_en_reg <= 1'b0;
            state <= IDLE;
        end
        else if((state == IDLE && next_state == ICACHE)) begin
            prefetch_en_reg <= 1'b1;
            state <= next_state;
        end
        else if(prefetch_en) begin
            prefetch_en_reg <= 1'b0;
            state <= next_state;
        end
        else if(state == PREFETCH && next_state == IDLE) begin
            prefetch_en_reg <= 1'b0;
            state <= next_state;
        end
        else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            prev_cl_addr <= 'x;
            prev_pf_addr <= 'x;
        end
        else if(state == ICACHE && next_state == IDLE) 
            prev_cl_addr <= {ibmem_addr[31:2], 2'b0};   
        else if(state == PREFETCH && next_state == IDLE) begin 
            prev_cl_addr <= pf_addr;
            prev_pf_addr <= pf_addr;
            ibmem_rdata_reg <= ibmem_rdata;
        end
    end

    assign pf_addr = prev_cl_addr + 32;
    assign prefetch_en = (flush || (prev_pf_addr == prev_cl_addr));

    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (dfp_read) next_state = ICACHE;
                else if(prefetch_en_reg && arbiter_idle) next_state = PREFETCH; 
                
            ICACHE: if (ibmem_resp || flush) next_state = IDLE;
            PREFETCH: if (ibmem_resp) next_state = IDLE;
        endcase
    end

    always_comb begin
        ibmem_addr = 32'h0;
        ibmem_read = 1'b0;
        dfp_rdata = 'x;
        dfp_resp = 1'b0;

        case (state)
            ICACHE: begin
                ibmem_addr = dfp_addr;
                ibmem_read = dfp_read;
                dfp_rdata = ibmem_rdata;
                dfp_resp = ibmem_resp;
                //end
            end
            PREFETCH: begin
                ibmem_addr = pf_addr;
                ibmem_read = 1'b1;
                //dfp_rdata = ibmem_rdata;
                //dfp_resp = ibmem_resp;
            end
            IDLE: begin
                if(dfp_addr == prev_pf_addr) begin
                    ibmem_read = 1'b0;
                    dfp_rdata = ibmem_rdata_reg;
                    dfp_resp = 1'b1;
                end
            end
        endcase

    end

    

endmodule
