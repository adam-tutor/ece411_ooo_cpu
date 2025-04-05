module prefetcher_stride
import rv32i_types::*;
(
    input clk, rst, flush,
    input   logic [31:0]   dfp_addr, //dfp addr to DCACHE
    //input   logic [31:0]   imem_addr,
    input   logic           dfp_read, //dfp read  to DCACHE
    output  logic [255:0]   dfp_rdata, //dfp rdata to DCACHE
    output  logic          dfp_resp, //dfp resp to DCACHE
    //input   logic          branch_taken,
    //input   logic           jump_taken,
    input   logic [255:0]   dbmem_rdata, //FROM ARBITER/MEM
    input   logic           dbmem_resp, //FROM ARBITER/MEM
    output  logic [31:0]    dbmem_addr, //TO ARBITER/MEM 
    output  logic           dbmem_read, //TO ARBITER/MEM
    input   logic           arbiter_idle //is the arbiter free?
);

    parameter NUM_ENTRIES = 16;

    enum logic [1:0] {DCACHE, PREFETCH, IDLE} state, next_state;

    logic prefetch_en, prefetch_en_reg;
    logic [31:0] prev_cl_addr, prev_pf_addr, pf_addr, pf_addr_reg;

    logic [255:0] dbmem_rdata_reg [NUM_ENTRIES];

    logic [31:0] prev_accessed_addrs [NUM_ENTRIES];
    logic [31:0] strides [NUM_ENTRIES];
    logic [31:0] prev_accessed_addrs_reg [NUM_ENTRIES];
    logic [31:0] strides_reg [NUM_ENTRIES];
    logic [31:0] prev_dfp_addr, prev_dfp_addr_reg;
    int index;
    int index_reg;
    int addr_count;


    always_ff @(posedge clk) begin
        if (rst) begin
            prefetch_en_reg <= 1'b1;
            state <= IDLE;
        end
        else if((state == IDLE && next_state == DCACHE)) begin
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
        if(rst || addr_count == NUM_ENTRIES) begin
            addr_count <= 0;
        end
        else if(dbmem_resp && dfp_read) begin
            addr_count <= addr_count + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            prev_cl_addr <= 'x;
            prev_pf_addr <= 'x;
            index_reg <= 'x;
            prev_dfp_addr_reg <= 'x;
            pf_addr_reg <= 'x;
            for(int i = 0; i < NUM_ENTRIES; i++) begin
                prev_accessed_addrs_reg[i] <= 'x;
                strides_reg[i] <= 'x;
            end
        end
        else if(state == DCACHE && next_state == IDLE) 
            prev_cl_addr <= {dbmem_addr[31:2], 2'b0};   
        else if(state == PREFETCH && next_state == IDLE) begin 
            prev_cl_addr <= pf_addr;
            prev_pf_addr <= pf_addr;
            dbmem_rdata_reg[addr_count] <= dbmem_rdata;
        end
        index_reg <= index;
        prev_dfp_addr_reg <= prev_dfp_addr;
        for(int i = 0; i < NUM_ENTRIES; i++) begin
            prev_accessed_addrs_reg[i] <= prev_accessed_addrs[i];
            strides_reg[i] <= strides[i];
        end
        pf_addr_reg <= pf_addr;
    end

    assign pf_addr = prev_accessed_addrs_reg[index] + strides_reg[index];
    assign prefetch_en = (flush || (prev_pf_addr == prev_cl_addr));

    always_comb begin
        next_state = state;
        index = index_reg;
        case (state)
            IDLE:
                if(dfp_read) next_state = DCACHE;
                else begin
                    for(int i = 0; i < NUM_ENTRIES; i++) begin
                        if((~prefetch_en_reg) && arbiter_idle && (prev_dfp_addr == prev_accessed_addrs[i])) begin
                            index = i;
                            next_state = PREFETCH; 
                        end
                    end
                end
                
            DCACHE: if (dbmem_resp || flush) next_state = IDLE;
            PREFETCH: if (dbmem_resp) next_state = IDLE;
            default: index = addr_count;
        endcase
    end

    always_comb begin
        dbmem_addr = 32'h0;
        dbmem_read = 1'b0;
        dfp_rdata = 'x;
        dfp_resp = 1'b0;
        prev_dfp_addr = prev_dfp_addr_reg;
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            prev_accessed_addrs[i] = prev_accessed_addrs_reg[i];
            strides[i] = strides_reg[i];
        end
        
        /*for (int i = 0; i < NUM_ENTRIES; i++) begin
            prev_accessed_addrs[i] = 32'd0;
            strides[i] = 32'd0;
        end*/

        if(rst) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                prev_accessed_addrs[i] = 32'd0;
                strides[i] = 32'd0;
            end
            prev_dfp_addr = 0;
        end
        else if (dbmem_resp) begin
            prev_accessed_addrs[addr_count] = prev_dfp_addr_reg;
            strides[addr_count] = dfp_addr - prev_dfp_addr_reg;
            prev_dfp_addr = dfp_addr;
            /*addr_count = addr_count + 1;
            if(addr_count == NUM_ENTRIES) begin
                addr_count = 0;
            end*/
        end

        case (state)
            DCACHE: begin
                dbmem_addr = dfp_addr;
                dbmem_read = dfp_read;
                dfp_rdata = dbmem_rdata;
                dfp_resp = dbmem_resp;
            end
            PREFETCH: begin
                dbmem_addr = pf_addr_reg;
                dbmem_read = 1'b1;
                if (dbmem_resp) begin
                    prev_accessed_addrs[addr_count] = pf_addr_reg;
                    strides[addr_count] = pf_addr_reg - prev_dfp_addr_reg;
                    prev_dfp_addr = pf_addr_reg;
                end
                //dfp_rdata = dbmem_rdata;
                //dfp_resp = dbmem_resp;
            end
            IDLE: begin
                dbmem_addr = dfp_addr;
                dbmem_read = dfp_read;
                for(int i = 0; i < NUM_ENTRIES; i++) begin
                    if(dfp_addr == prev_accessed_addrs[i]) begin
                        dfp_rdata = dbmem_rdata_reg[i];
                        dfp_resp = dbmem_resp;
                    end
                    else if(dbmem_resp) begin
                        dfp_resp = 1'b1;
                    end
                end
            end
        endcase

    end

    

endmodule
