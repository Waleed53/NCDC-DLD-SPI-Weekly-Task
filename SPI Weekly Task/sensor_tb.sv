
module tb_sensor_acq();
    reg clk = 0;
    reg reset = 1;
    wire spi_start, spi_complete;
    wire [15:0] spi_address;
    wire [7:0] spi_write_data, spi_read_data;
    wire spi_read_write;

    reg sensor_read_request = 0;
    reg [2:0] sensor_select = 3'd5; 
    reg continuous_mode = 0;
    reg [7:0] sample_period = 8'd10;

    always #5 clk = ~clk; 

    sensor_data_acquisition dut (
        .clk(clk),
        .reset(reset),
        .spi_address(spi_address),
        .spi_write_data(spi_write_data),
        .spi_read_data(spi_read_data),
        .spi_start(spi_start),
        .spi_complete(spi_complete),
        .spi_read_write(spi_read_write),
        .sensor_read_request(sensor_read_request),
        .sensor_select(sensor_select),
        .continuous_mode(continuous_mode),
        .sample_period(sample_period),
        .temperature_raw(),
        .temperature_celsius(),
        .detector_power(),
        .sensors_valid(),
        .conversion_complete(),
        .active_sensor(),
        .adc_error()
    );

    adar1000_spi_slave_mock mock (
        .clk(clk),
        .reset(reset),
        .spi_address(spi_address),
        .spi_write_data(spi_write_data),
        .spi_read_data(spi_read_data),
        .spi_start(spi_start),
        .spi_complete(spi_complete),
        .spi_read_write(spi_read_write)
    );

    initial begin
        #20 reset = 0;
        #10 sensor_read_request = 1;
        #10 sensor_read_request = 0;

        #5000 $stop;
    end
endmodule