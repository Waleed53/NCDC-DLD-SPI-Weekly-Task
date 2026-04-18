`timescale 1ns / 1ps

module tb_adar1000_top;

    reg clk = 0;
    reg rst_n = 0;

    reg mode_switch = 0;           
    reg start_operation = 0;
    reg [6:0] beam_index_in = 7'd0;
    reg sequential_mode = 0;
    reg [6:0] seq_start = 7'd0;
    reg [6:0] seq_end = 7'd0;
    reg tx_select = 0;
    reg [1:0] chip_addr = 2'b00;

    reg [2:0] sensor_select = 3'd0;
    reg continuous_mode = 0;
    reg [7:0] sample_period = 8'd10;

    wire spi_sclk;
    wire spi_csb;
    wire spi_sdio_out;
    wire spi_sdio_oe;
    reg  spi_sdi = 0;  

    wire busy;
    wire done;
    wire error;

    wire [7:0] temperature_raw;
    wire signed [7:0] temperature_celsius;
    wire [7:0] detector_power0;
    wire [7:0] detector_power1;
    wire [7:0] detector_power2;
    wire [7:0] detector_power3;
    wire sensors_valid;

    adar1000_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_switch(mode_switch),
        .start_operation(start_operation),
        .beam_index_in(beam_index_in),
        .sequential_mode(sequential_mode),
        .seq_start(seq_start),
        .seq_end(seq_end),
        .tx_select(tx_select),
        .chip_addr(chip_addr),
        .sensor_select(sensor_select),
        .continuous_mode(continuous_mode),
        .sample_period(sample_period),
        .spi_sclk(spi_sclk),
        .spi_csb(spi_csb),
        .spi_sdio_out(spi_sdio_out),
        .spi_sdio_oe(spi_sdio_oe),
        .spi_sdi(spi_sdi),
        .busy(busy),
        .done(done),
        .error(error),
        .temperature_raw(temperature_raw),
        .temperature_celsius(temperature_celsius),
        .detector_power0(detector_power0),
        .detector_power1(detector_power1),
        .detector_power2(detector_power2),
        .detector_power3(detector_power3),
        .sensors_valid(sensors_valid)
    );

    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        start_operation = 0;
        #100;
        rst_n = 1;
        wait(done);
        #10;
        mode_switch = 0;          
        beam_index_in = 7'd15;
        sequential_mode = 1'b1;
        seq_start = 7'd10;
        seq_end = 7'd20;
        tx_select = 1'b1;
        chip_addr = 2'b01;

        #20;
        start_operation = 1;
        #20;
        start_operation = 0;
      $display("\n=== READ SENSORS MODE COMPLETE ===");
                      $display("Error flag: %0b", error);
                      $display("Sensor select: %d", sensor_select);
                      $display("Continuous mode: %0b", continuous_mode);
                      $display("Sample period: %d", sample_period);
                      $display("Temperature raw: %d", temperature_raw);
                      $display("Temperature Celsius: %d", temperature_celsius);
                      $display("Detector Powers:");
                      $display("  Detector 0: %d", detector_power0);
                      $display("  Detector 1: %d", detector_power1);
                      $display("  Detector 2: %d", detector_power2);
                      $display("  Detector 3: %d", detector_power3);
                      $display("Sensors valid flag: %0b", sensors_valid);
                
        wait(done);
        #10;

        $display("\n=== WRITE BEAMS MODE COMPLETE ===");
        $display("Error flag: %0b", error);
        $display("Beam index input: %d", beam_index_in);
        $display("Sequential mode: %0b", sequential_mode);
        $display("Sequence start: %d", seq_start);
        $display("Sequence end: %d", seq_end);
        $display("TX Select: %0b", tx_select);
        $display("Chip address: %b", chip_addr);

        #100;

        mode_switch = 1;          
        sensor_select = 3'd5;     
        continuous_mode = 1'b0;
        sample_period = 8'd20;

        #20;
        start_operation = 1;
        #20;
        start_operation = 0;
      

        #100;
        $finish;
    end

endmodule


