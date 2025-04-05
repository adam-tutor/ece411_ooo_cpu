module prefetcher_stride
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

    parameter NUM_ENTRIES = 10;

    enum logic [1:0] {ICACHE, PREFETCH, IDLE} state, next_state;

    logic prefetch_en, prefetch_en_reg;
    logic [31:0] prev_cl_addr, prev_pf_addr, pf_addr;

    logic [255:0] ibmem_rdata_reg;

    logic [31:0] saved_addresses [NUM_ENTRIES];
    logic [31:0] strides [NUM_ENTRIES];
    logic [31:0] last_addr;
    int entry_index;
    int lru_counter;
    logic lru_counter_flag;


    always_ff @(posedge clk) begin
        if (rst) begin
            prefetch_en_reg <= 1'b1;
            state <= IDLE;
        end
        else if((state == IDLE && next_state == ICACHE)) begin
            prefetch_en_reg <= 1'b0;
            state <= next_state;
        end
        else if(prefetch_en) begin
            prefetch_en_reg <= 1'b1;
            state <= next_state;
        end
        else if(state == PREFETCH && next_state == IDLE) begin
            prefetch_en_reg <= 1'b1;
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

    assign pf_addr = saved_addresses[entry_index] + strides[entry_index];
    assign prefetch_en = (flush || (prev_pf_addr == prev_cl_addr));

    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if(dfp_read) next_state = ICACHE;
                else begin
                    for(int i = 0; i < NUM_ENTRIES; i++) begin
                        if((~prefetch_en_reg) && arbiter_idle && (prev_cl_addr == saved_addresses[i])) begin
                            entry_index = i;
                            next_state = PREFETCH; 
                        end
                    end
                end
                
            ICACHE: if (ibmem_resp || flush) next_state = IDLE;
            PREFETCH: if (ibmem_resp) next_state = IDLE;
        endcase
    end

    always_comb begin
        ibmem_addr = 32'h0;
        ibmem_read = 1'b0;
        dfp_rdata = 'x;
        dfp_resp = 1'b0;

        if(rst) begin
            lru_counter = 0;
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                saved_addresses[i] = 32'd0;
                strides[i] = 32'd0;
            end
            last_addr = 32'd0;
        end
        else if (dfp_read && ibmem_resp) begin
            saved_addresses[lru_counter] = dfp_addr;
            strides[lru_counter] = dfp_addr - last_addr;
            last_addr = dfp_addr;
            lru_counter_flag = 1'b1;
            if (lru_counter == NUM_ENTRIES) begin
                lru_counter = 0;
            end
        end
        else if(lru_counter_flag == 1'b1) begin
            lru_counter = lru_counter + 1'b1;
            lru_counter_flag = 1'b0;
        end

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
