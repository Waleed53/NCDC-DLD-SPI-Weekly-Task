`timescale 1ns/1ps

module tb_spi_master();

    reg clk = 0;
    reg reset = 1;
    always #5 clk = ~clk; 
    reg [15:0] address;
    reg [7:0]  write_data;
    reg        start_transaction;
    reg        read_write; 
    wire [7:0] read_data;
    wire       transaction_complete;
    wire       transaction_error;

    wire sclk;
    wire csb;
    wire sdio_out;
    wire sdio_oe;
    reg  sdi;

    spi_master_controller dut (
        .clk(clk),
        .reset(reset),
        .address(address),
        .write_data(write_data),
        .start_transaction(start_transaction),
        .read_write(read_write),
        .read_data(read_data),
        .transaction_complete(transaction_complete),
        .transaction_error(transaction_error),
        .sclk(sclk),
        .csb(csb),
        .sdio_out(sdio_out),
        .sdio_oe(sdio_oe),
        .sdi(sdi)
    );

    reg [7:0]  response_byte;
    reg [7:0]  response_shift;
    integer    bitcnt;
    integer    resp_bitpos;

    initial begin
        bitcnt = 0;
        resp_bitpos = 7;
        sdi = 1'b0;
    end

    always @(negedge sclk or posedge csb) begin
        if (csb) begin
            bitcnt <= 0;
            resp_bitpos <= 7;
            sdi <= 1'b0;
        end else begin
            bitcnt <= bitcnt + 1;

            if (bitcnt == 16) begin
                response_byte  <= 8'hA5; 
                response_shift <= 8'hA5;
                resp_bitpos    <= 7;
            end

            if (bitcnt >= 16 && bitcnt < 24) begin
                sdi <= response_shift[resp_bitpos];
                if (resp_bitpos == 0)
                    resp_bitpos <= 7;
                else
                    resp_bitpos <= resp_bitpos - 1;
            end else begin
                sdi <= 1'b0;
            end
        end
    end

    initial begin
        $display("Test1: register write");
        #20 reset = 0;

        address = 16'h0032;
        write_data = 8'h5A;
        read_write = 0;
        start_transaction = 1; #10 start_transaction = 0;
        wait(transaction_complete);

        $display("Test1: COMPLETE");

        $display("Test2: register read");
        address = 16'h0033;
        read_write = 1;
        start_transaction = 1; #10 start_transaction = 0;
        wait(transaction_complete);
        $display("Test2: COMPLETE, read = 0x%0h", read_data);

        $display("Test3: back-to-back");
        address = 16'h1000;
        write_data = 8'h11;
        read_write = 0;
        start_transaction = 1; #10 start_transaction = 0;
        wait(transaction_complete);

        address = 16'h1001;
        write_data = 8'h22;
        read_write = 0;
        start_transaction = 1; #10 start_transaction = 0;
        wait(transaction_complete);

        $display("Test3: back-to-back done");

        #200 $display("All tests finished.");
        $stop;
    end

endmodule
