module queue 
import rv32i_types::*;
#(
            parameter               NUM_ENTRIES = 16,
            parameter               DATA_WIDTH  = 32
)
(
    input   logic                   clk,
    input   logic                   rst,
    input   logic                   flush,
    input   logic                   stall, 

    input   logic                   enqueue,
    input   logic [DATA_WIDTH-1:0]  enqueue_wdata,

    input   logic                   dequeue,
    output  logic [DATA_WIDTH-1:0]  dequeue_rdata,

    output  logic                   full,
    output  logic                   empty
);

    localparam              Q_INDEX    =  $clog2(NUM_ENTRIES);

    logic   [DATA_WIDTH-1:0]     entries [NUM_ENTRIES];

    logic   [Q_INDEX:0]     head_ptr;
    logic   [Q_INDEX:0]     tail_ptr;

    // From Lab Slides
    assign full = (
        (head_ptr[Q_INDEX-1:0] == tail_ptr[Q_INDEX-1:0]) &&
        (head_ptr[Q_INDEX] != tail_ptr[Q_INDEX])
    );
    assign empty = (head_ptr == tail_ptr);


    always_ff @(posedge clk) begin
        if(rst || flush) begin
            head_ptr <= '0;
            tail_ptr <= '0;
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                entries[i] <= '0;
            end
            dequeue_rdata <= '0;
        end
        else begin
            //Enqueue
            if(enqueue && (full == '0)) begin
                entries[tail_ptr[Q_INDEX-1:0]] <= enqueue_wdata;
                tail_ptr <= tail_ptr + 1'b1;
            end
            //Dequeue
            if(dequeue && (empty == '0)) begin
                dequeue_rdata <= entries[head_ptr[Q_INDEX-1:0]];
                head_ptr <= head_ptr + 1'b1;
            end
            else if (stall) begin
                dequeue_rdata <= dequeue_rdata;
            end 
            else begin
                dequeue_rdata <= '0;
            end 
        end
    end

endmodule : queue
