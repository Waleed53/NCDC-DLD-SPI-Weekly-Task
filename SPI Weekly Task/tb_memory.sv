`timescale 1ns/1ps
module memory_data_manager_full_tb;
    reg clk = 0;
    always #5 clk = ~clk; // 100 MHz

    reg rst_n;

    wire start_transaction;
    wire [15:0] address;
    wire [7:0] write_data;
    wire read_write;
    wire transaction_complete;
    wire [7:0] read_data;
    wire transaction_error;
    wire spi_busy;

    wire sclk;
    wire csb;
    wire sdio_out;
    wire sdio_oe;
    wire sdi; 
    wire tx_load, rx_load;

    reg start_send;
    reg [6:0] beam_index_in;
    reg sequential_mode;
    reg [6:0] seq_start, seq_end;
    reg tx_select;
    reg [1:0] chip_addr;

    wire [6:0] current_beam;
    wire done;
    wire error;

    memory_data_manager_write #(
        .LOAD_PULSE_CYCLES(8)
    ) manager (
        .clk(clk),
        .rst_n(rst_n),
        .start_transaction(start_transaction),
        .address(address),
        .write_data(write_data),
        .read_write(read_write),
        .transaction_complete(transaction_complete),
        .spi_busy(spi_busy),

        .tx_load(tx_load),
        .rx_load(rx_load),

        .start_send(start_send),
        .beam_index_in(beam_index_in),
        .sequential_mode(sequential_mode),
        .seq_start(seq_start),
        .seq_end(seq_end),
        .tx_select(tx_select),
        .chip_addr(chip_addr),

        .current_beam(current_beam),
        .done(done),
        .error(error)
    );

    spi_master_controller #(
        .SYS_CLK_FREQ(100_000_000),
        .SPI_CLK_FREQ(10_000_000)
    ) spi_master (
        .clk(clk),
        .reset(~rst_n), 
        .sclk(sclk),
        .csb(csb),
        .sdio_out(sdio_out),
        .sdio_oe(sdio_oe),
        .sdi(sdi),

        .start_transaction(start_transaction),
        .address(address),
        .write_data(write_data),
        .read_write(read_write),

        .read_data(read_data),
        .transaction_complete(transaction_complete),
        .transaction_error(transaction_error),
        .spi_busy(spi_busy)
    );

    spi_slave_mock slave (
        .sclk(sclk),
        .csb(csb),
        .sdio_out(sdio_out),
        .sdio_oe(sdio_oe),
        .sdi(sdi),
        .last_frame(), .last_addr(), .last_data()
    );

    

    initial begin
        $display("TB start - full SPI bit-level test");
        rst_n = 0;
        start_send = 0;
        beam_index_in = 0;
        sequential_mode = 0;
        seq_start = 0; seq_end = 0;
        tx_select = 0;
        chip_addr = 2'b00;
        #200;
        rst_n = 1;
        #200;

        $display("[%0t] starting beam 0 write", $time);
        start_send = 1;
        #10;
        start_send = 0;

        wait (done == 1);
        #50;
        $display("[%0t] done, current_beam=%0d", $time, current_beam);

        $display("Note: inspect waveform for sclk/csb/sdio_out/sdi to verify frames.");
        $display("TB finished");
        #200;
        $stop;
    end

endmodule
