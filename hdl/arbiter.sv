module arbiter
import rv32i_types::*;
(
    input clk, rst, 
    // flush,
    
    //I-Mem and D-Mem
    input logic   [31:0]  ibmem_addr, dbmem_addr,
    input logic           ibmem_read, dbmem_read,
    input logic           ibmem_write, dbmem_write,
    input logic   [255:0] ibmem_wdata, dbmem_wdata,

    output logic   [255:0] ibmem_rdata, dbmem_rdata,
    output logic           ibmem_resp, dbmem_resp,
    
    //Banked Memory
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    output  logic   [255:0] dfp_wdata,

    input   logic   [255:0] dfp_rdata,
    input   logic           dfp_resp
);

enum logic [2:0] {ICACHE, DCACHE_READ, DCACHE_WRITE, IDLE, WAIT} state, next_state;
logic   [255:0] temp_imem_wdata;
logic           temp_imem_write;

assign temp_imem_write = ibmem_write;
assign temp_imem_wdata = ibmem_wdata;

always_ff @( posedge clk ) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always_comb begin
    next_state = state;
    dfp_addr  = '0;
    dfp_wdata = '0;
    dfp_read  = '0;
    dfp_write = '0;
    
    ibmem_rdata = '0;
    ibmem_resp = '0;
    dbmem_rdata = 'x;
    dbmem_resp = '0;

    if(state == IDLE) begin
        if(dbmem_write) begin
            next_state = DCACHE_WRITE;
        end
        else if(dbmem_read) begin
            next_state = DCACHE_READ;
        end
        else if(ibmem_read) begin
            next_state = ICACHE;
        end
    end

    if(state == ICACHE) begin
        if(dfp_resp) begin
            ibmem_rdata = dfp_rdata;
            ibmem_resp = dfp_resp;
            next_state = IDLE;
        end
        else begin
            dfp_addr = ibmem_addr;
            dfp_read = ibmem_read;
        end
    end

    if(state == DCACHE_READ) begin
        if(dfp_resp) begin
            dbmem_rdata = dfp_rdata;
            dbmem_resp = dfp_resp;
            next_state = IDLE;
        end
        else begin
            dfp_addr = dbmem_addr;
            dfp_read = dbmem_read;
        end
    end
    if(state == DCACHE_WRITE) begin
        if(dfp_resp) begin
            dbmem_resp = dfp_resp;
            next_state = IDLE;
        end
        else begin
            dfp_addr = dbmem_addr;
            dfp_write = dbmem_write;
            dfp_wdata = dbmem_wdata;
        end
    end
end

endmodule