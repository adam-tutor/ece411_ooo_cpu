module cache 
import rv32i_types::*;
#(
    parameter NUM_SET = 16,
    parameter NUM_WAY = 4
)
(
    input   logic           clk,
    input   logic           rst,
    input   logic           flush,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

    localparam SET_IDX = $clog2(NUM_SET);
    localparam OFFSET_BITS = 5;
    localparam CPU_TAG_BITS = 32 - SET_IDX - OFFSET_BITS;

    logic   [31:0]  ufp_addr_r;
    logic   [3:0]   ufp_rmask_r;
    logic   [3:0]   ufp_wmask_r;
    logic   [31:0]  ufp_rdata_r;
    logic   [31:0]  ufp_wdata_r;
    logic           ufp_resp_r;
    logic           chip_select;
    // Data Arrays Input 
    logic data_we[NUM_WAY];
    logic [31:0] data_wmask[NUM_WAY];
    logic [255:0] data_in[NUM_WAY];
    logic [255:0] data_out[NUM_WAY];
    // Tag Arrays Input 
    logic tag_we[NUM_WAY];
    logic [CPU_TAG_BITS:0] tag_in[NUM_WAY];
    logic [CPU_TAG_BITS:0] tag_out[NUM_WAY];
    // Valid Arrays Input 
    logic valid_we[NUM_WAY];
    logic valid_in[NUM_WAY];
    logic valid_out[NUM_WAY];

    logic [SET_IDX - 1:0] set_index;
    logic [CPU_TAG_BITS - 1:0] cpu_tag;
    logic [4:0] cpu_offset;


    generate for (genvar i = 0; i < NUM_WAY; i++) begin : arrays
        mp_cache_data_array  data_array (
            .clk0       (clk),
            .csb0       (chip_select),
            .web0       (data_we[i]),
            .wmask0     (data_wmask[i]),
            .addr0      (set_index),
            .din0       (data_in[i]),
            .dout0      (data_out[i])
        );
        //addr -> set index
        mp_cache_tag_array  tag_array (
            .clk0       (clk),
            .csb0       (chip_select),
            .web0       (tag_we[i]),
            .addr0      (set_index),
            .din0       (tag_in[i]),
            .dout0      (tag_out[i])
        );
        ff_array #(.S_INDEX(SET_IDX), .WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (chip_select),
            .web0       (valid_we[i]),
            .addr0      (set_index),
            .din0       (valid_in[i]),
            .dout0      (valid_out[i])
        );
    end endgenerate

    
    assign cpu_offset = ufp_addr_r[4:0];
    assign set_index  = ufp_addr_r[5+:SET_IDX];  
    assign cpu_tag    = ufp_addr_r[(5 + SET_IDX)+:CPU_TAG_BITS]; 


    // PLRU Policy
    logic [2:0] plru_sv, plru_dv, plru_mask;
    //CD AB AB/CD
    //L2 L1 L0
    logic [SET_IDX - 1:0] plru_sr, plru_dr;
    logic regf_we;
    logic [1:0] new_way;

    plrufile #(.NUM_SET(NUM_SET), .SET_IDX(SET_IDX)) plru(
        .*
    );

    always_comb begin
        plru_sr = set_index;
        //Replace Way A
        if (plru_sv[1:0] == 2'b11) begin
            new_way = 2'b00;
        end
        //Replace Way B
        else if (plru_sv[1:0] == 2'b01) begin
            new_way = 2'b01;
        end 
        //Replace Way C
        else if ((plru_sv[2] == 1'b1) && (plru_sv[0] == 1'b0)) begin
            new_way = 2'b10;
        end 
        //Replace Way D
        else if ((plru_sv[2] == 1'b0) && (plru_sv[0] == 1'b0)) begin
            new_way = 2'b11;
        end
        else begin
            new_way = 2'b00;
        end
    end

    logic ignore_data;
    // FSM MACHINE FOR CACHE
    enum int unsigned {
        s_idle, s_tagcheck,
        s_allocate, s_writeback, s_stall, s_idle_two
    } state, state_next;

    always_ff @( posedge clk ) begin
        if(flush) ignore_data <= 1'b1;
        if (rst) begin
            state <= s_idle;
            ufp_addr_r <= '0;
            ufp_rmask_r <= '0;
            ufp_wmask_r <= '0;
            ufp_wdata_r <= '0;
            ufp_rdata <= '0;
            ufp_resp <= '0;
        end else if (state == s_idle && state_next != s_idle) begin
            state <= state_next;
            ufp_addr_r <= ufp_addr;
            ufp_rmask_r <= ufp_rmask;
            ufp_wmask_r <= ufp_wmask;
            ufp_wdata_r <= ufp_wdata;
            ufp_rdata <= ufp_rdata_r;
            ufp_resp <= ufp_resp_r;
            if(ignore_data) ignore_data <= 1'b0;
        end else begin
            if(ignore_data && ufp_resp_r) begin
                state <= state_next;
                ufp_rdata <= '0;
                ufp_resp <= 1'b0;
                ignore_data <= 1'b0;
            end
            else begin
                state <= state_next;
                ufp_rdata <= ufp_rdata_r;
                ufp_resp <= ufp_resp_r;
            end
        end
    end

    always_comb begin
        //State
        state_next = state;
        //CPU Output
        ufp_resp_r = 1'b0;
        ufp_rdata_r = 'x;
        //Write 
        data_wmask[0] = '0;
        data_wmask[1] = '0;
        data_wmask[2] = '0;
        data_wmask[3] = '0;

        data_we[0] = 1'b1;
        data_we[1] = 1'b1;
        data_we[2] = 1'b1;
        data_we[3] = 1'b1;

        data_in[0] = {256{1'bx}};
        data_in[1] = {256{1'bx}};
        data_in[2] = {256{1'bx}};
        data_in[3] = {256{1'bx}};

        tag_we[0] = 1'b1;
        tag_we[1] = 1'b1;
        tag_we[2] = 1'b1;
        tag_we[3] = 1'b1;

        tag_in[0] = {(CPU_TAG_BITS+1){1'bx}};
        tag_in[1] = {(CPU_TAG_BITS+1){1'bx}};
        tag_in[2] = {(CPU_TAG_BITS+1){1'bx}};
        tag_in[3] = {(CPU_TAG_BITS+1){1'bx}};
        
        valid_we[0] = 1'b1;
        valid_we[1] = 1'b1;
        valid_we[2] = 1'b1;
        valid_we[3] = 1'b1;

        valid_in[0] = 1'bx;
        valid_in[1] = 1'bx;
        valid_in[2] = 1'bx;
        valid_in[3] = 1'bx;

        dfp_addr = 'x;
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_wdata = {256{1'bx}};
        
        //PLRU write
        regf_we = 1'b0;
        plru_dr = set_index;
        plru_dv = 3'b000;
        plru_mask = 3'b000;
        chip_select = 1'b1;

        unique case (state)
            s_idle: begin
                if((ufp_rmask != 4'd0) || (ufp_wmask != 4'd0)) begin
                    state_next = s_idle_two;
                end
                else begin
                    state_next = s_idle;
                end
            end
            s_idle_two: begin
                if((ufp_rmask_r != 4'd0) || (ufp_wmask_r != 4'd0)) begin
                    state_next = s_tagcheck;
                end
                else begin
                    state_next = s_idle;
                end
                chip_select = 1'b0;
            end
            s_tagcheck: begin 
                if(ufp_rmask_r != 4'd0) begin
                    if(valid_out[0] && (tag_out[0][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        ufp_rdata_r = data_out[0][32*cpu_offset[4:2]+:32];
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;


                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'bx00;
                        plru_mask = 3'b011;

                    end
                    else if(valid_out[1] && (tag_out[1][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        ufp_rdata_r = data_out[1][32*cpu_offset[4:2]+:32]; 
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'bx10;
                        plru_mask = 3'b011;
                        
                    end
                    else if(valid_out[2] && (tag_out[2][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        ufp_rdata_r = data_out[2][32*cpu_offset[4:2]+:32];
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'b0x1;
                        plru_mask = 3'b101;

                    end
                    else if(valid_out[3] && (tag_out[3][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        ufp_rdata_r = data_out[3][32*cpu_offset[4:2]+:32];
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'b1x1;
                        plru_mask = 3'b101;

                    end
                    else begin
                        if(valid_out[new_way] && tag_out[new_way][CPU_TAG_BITS] == 1'b1) begin
                            //Dirty
                            state_next = s_writeback;
                        end 
                        else begin
                            //Clean
                            state_next = s_allocate;
                        end    
                    end
                end
                else begin
                    //******************************** WRITE CASE ********************************//
                    //Hit Case
                    if(valid_out[0] && (tag_out[0][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        data_wmask[0] = {{28{1'b0}}, ufp_wmask_r} << ufp_addr_r[4:0];
                        data_we[0] = 1'b0;
                        data_in[0] = {8{ufp_wdata_r}};
                        tag_we[0] = 1'b0;
                        tag_in[0] = {1'b1, cpu_tag};
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;
                        chip_select = 1'b0;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'bx00;
                        plru_mask = 3'b011;

                    end
                    else if(valid_out[1] && (tag_out[1][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        data_wmask[1] = {{28{1'b0}}, ufp_wmask_r} << ufp_addr_r[4:0];
                        data_we[1] = 1'b0;
                        data_in[1] = {8{ufp_wdata_r}};
                        tag_we[1] = 1'b0;
                        tag_in[1] = {1'b1, cpu_tag};
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;
                        chip_select = 1'b0;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'bx10;
                        plru_mask = 3'b011;

                    end
                    else if(valid_out[2] && (tag_out[2][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        data_wmask[2] = {{28{1'b0}}, ufp_wmask_r} << ufp_addr_r[4:0];
                        data_we[2] = 1'b0;
                        data_in[2] = {8{ufp_wdata_r}};
                        tag_we[2] = 1'b0;
                        tag_in[2] = {1'b1, cpu_tag};
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;
                        chip_select = 1'b0;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'b0x1;
                        plru_mask = 3'b101;
                    end
                    else if(valid_out[3] && (tag_out[3][CPU_TAG_BITS - 1:0] == cpu_tag)) begin
                        data_wmask[3] = {{28{1'b0}}, ufp_wmask_r} << ufp_addr_r[4:0];
                        data_we[3] = 1'b0;
                        data_in[3] = {8{ufp_wdata_r}};
                        tag_we[3] = 1'b0;
                        tag_in[3] = {1'b1, cpu_tag};
                        if(!flush) ufp_resp_r = 1'b1;
                        else ufp_resp_r = 1'b0;
                        state_next = s_idle;
                        chip_select = 1'b0;

                        //Update PLRU
                        regf_we = 1'b1;
                        plru_dr = set_index;
                        plru_dv = 3'b1x1;
                        plru_mask = 3'b101;

                    end
                    //Miss Case
                    else begin
                        if(valid_out[new_way] && tag_out[new_way][CPU_TAG_BITS] == 1'b1) begin
                            //Dirty
                            state_next = s_writeback;
                        end 
                        else begin
                            //Clean
                            state_next = s_allocate;
                        end    
                    end
                end
            end
        
            s_allocate: begin
                dfp_addr = {ufp_addr_r[31:5], {5{1'b0}}};
                dfp_read = 1'b1;
                if(dfp_resp) begin
                    valid_we[new_way] = 1'b0;
                    valid_in[new_way] = 1'b1;
                    tag_we[new_way] = 1'b0;
                    tag_in[new_way] = {1'b0, cpu_tag};
                    data_we[new_way] = 1'b0;
                    data_in[new_way] = dfp_rdata;
                    data_wmask[new_way] = '1;
                    state_next = s_stall;
                    chip_select = 1'b0;
                end
                else begin
                    state_next = s_allocate;
                end
            end
            s_writeback: begin
                dfp_addr = {tag_out[new_way][CPU_TAG_BITS - 1:0], set_index, {5{1'b0}}};
                dfp_write = 1'b1;
                dfp_wdata = data_out[new_way]; 

                if(dfp_resp) begin
                    state_next = s_allocate;
                end
                else begin
                    state_next = s_writeback;
                end
            end
            s_stall: begin
                state_next = s_tagcheck;
            end

            default: begin
                state_next = s_idle;
            end
        endcase
    end

endmodule