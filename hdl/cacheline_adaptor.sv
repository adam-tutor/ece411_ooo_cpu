module cacheline_adaptor(
    input clk,
    input rst,

   //cache
    input  logic   [31:0]  dfp_addr,
    input  logic           dfp_read,
    input  logic           dfp_write,
    output logic   [255:0] dfp_rdata,
    input  logic   [255:0] dfp_wdata,
    output logic           dfp_resp,

   //memory
    output logic  [31:0]      bmem_addr,
    output logic              bmem_read,
    output logic              bmem_write,
    output logic  [63:0]      bmem_wdata,

    input logic               bmem_ready,
    input logic   [31:0]      bmem_raddr,
    input logic   [63:0]      bmem_rdata,
    input logic               bmem_rvalid
    
);

logic [2:0] count;
logic [255:0] buffer;
enum logic [1:0] { IDLE, READ, WRITE, DONE } prev_fsm_state_reg, prev_fsm_state, fsm_state, fsm_next_state;
logic   [31:0]      bmem_raddr_temp;

assign bmem_raddr_temp = bmem_raddr;

always_ff @(posedge clk) begin
    if (rst)
        fsm_state <= IDLE;
    else begin
        fsm_state <= fsm_next_state;
        prev_fsm_state_reg <= prev_fsm_state; 
        if (fsm_state == DONE) begin
            count <= '0;
        end
        else if(fsm_state == IDLE) begin
            if (dfp_write && bmem_ready) begin
                count <= count + 3'd1;
            end
        end
        else if (fsm_state == READ) begin
            if(count < 4) begin
                if(bmem_rvalid) begin
                    if(count == 3'd3) begin
                        count <= '0;
                    end
                    else count <= count + 1'b1;
                    buffer[64*count[2:0]+:64] <= bmem_rdata;
                end
                else begin
                    count <= count;
                end
            end
            else count <= '0;
        end
        else if (fsm_state == WRITE) begin
            if(count < 4) begin
                if (dfp_write && bmem_ready) begin
                    count <= count + 3'd1;
                end
                else begin
                    count <= count;
                end
            end
            else count <= '0;
        end
    end
end


always_comb begin

    bmem_read = '0;
    bmem_write = '0;
    dfp_resp = '0;
    bmem_wdata = 64'h0;
    fsm_next_state = fsm_state;
    prev_fsm_state = fsm_state;
    bmem_addr = dfp_addr;
    dfp_rdata = 'x;

    if(fsm_state == IDLE) begin
        if (dfp_read && bmem_ready) begin
            fsm_next_state = READ;
            bmem_read = 1'b1;
        end 
        else if (dfp_write && bmem_ready) begin
            fsm_next_state = WRITE;
            bmem_write = 1'b1;
            bmem_wdata = dfp_wdata[count*64 +: 64];
        end
    end
    else if(fsm_state == READ) begin
        bmem_read = 1'b0;
        if((count == 3'd3) && bmem_rvalid) begin
            fsm_next_state = DONE;
            prev_fsm_state = READ;
        end
    end
    else if(fsm_state == WRITE) begin    
        if(count < 4) begin
            if (dfp_write && bmem_ready) begin
                bmem_write = 1'b1;
                bmem_wdata = dfp_wdata[count*64 +: 64];
                fsm_next_state = WRITE;
            end
            else begin
                bmem_write = 1'b0;
                bmem_wdata = 'x;
                fsm_next_state = WRITE;
            end
        end
        else begin
            prev_fsm_state = WRITE;
            fsm_next_state = DONE;
        end
    end
    else if(fsm_state == DONE) begin
        fsm_next_state = IDLE;
        if(prev_fsm_state_reg == READ) begin
            dfp_rdata = buffer;
        end
        dfp_resp = 1'b1;
        bmem_read = 1'b0;
        bmem_write = 1'b0;
    end
    else begin
        fsm_next_state = IDLE;
    end
end

endmodule : cacheline_adaptor
