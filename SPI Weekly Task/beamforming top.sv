
`timescale 1ns / 1ps
module adar1000_top (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        mode_switch,  
    input  wire        start_operation, 
    input  wire [6:0]  beam_index_in,   
    input  wire        sequential_mode,
    input  wire [6:0]  seq_start,
    input  wire [6:0]  seq_end,
    input  wire        tx_select,       
    input  wire [1:0]  chip_addr,      

    input  wire [2:0]  sensor_select,   
    input  wire        continuous_mode,
    input  wire [7:0]  sample_period,

    output wire        spi_sclk,
    output wire        spi_csb,
    output wire        spi_sdio_out,
    output wire        spi_sdio_oe,
    input  wire        spi_sdi,

    output wire        busy,
    output wire        done,
    output wire        error,

    output wire [7:0]  temperature_raw,
    output wire signed [7:0] temperature_celsius,
    output wire [7:0]  detector_power0,
    output wire [7:0]  detector_power1,
    output wire [7:0]  detector_power2,
    output wire [7:0]  detector_power3,
    output wire        sensors_valid
);

    wire         spi_start_mem;
    wire [15:0]  spi_address_mem;
    wire [7:0]   spi_write_data_mem;
    wire         spi_read_write_mem;

    wire         spi_start_sensor;
    wire [15:0]  spi_address_sensor;
    wire [7:0]   spi_write_data_sensor;
    wire         spi_read_write_sensor;

    reg          start_transaction;
    reg  [15:0]  spi_address;
    reg  [7:0]   spi_write_data;
    reg          spi_read_write;

    wire [7:0]   spi_read_data;
    wire         transaction_complete;
    wire         transaction_error;
    wire         spi_busy;

    wire mem_done, mem_error;
    wire sensor_done, sensor_error;

    reg mem_start_send;
    reg sensor_start_req;

    spi_master_controller spi_master_i (
        .clk(clk),
        .reset(~rst_n),
        .sclk(spi_sclk),
        .csb(spi_csb),
        .sdio_out(spi_sdio_out),
        .sdio_oe(spi_sdio_oe),
        .sdi(spi_sdi),

        .start_transaction(start_transaction),
        .address(spi_address),
        .write_data(spi_write_data),
        .read_write(spi_read_write),
        .read_data(spi_read_data),
        .transaction_complete(transaction_complete),
        .transaction_error(transaction_error),
        .spi_busy(spi_busy)
    );

    memory_data_manager_write memory_mgr_i (
        .clk(clk),
        .rst_n(rst_n),

        .start_transaction(spi_start_mem),
        .address(spi_address_mem),
        .write_data(spi_write_data_mem),
        .read_write(spi_read_write_mem),
        .transaction_complete(transaction_complete),
        .spi_busy(spi_busy),

        .tx_load(),
        .rx_load(),

        .start_send(mem_start_send),
        .beam_index_in(beam_index_in),
        .sequential_mode(sequential_mode),
        .seq_start(seq_start),
        .seq_end(seq_end),
        .tx_select(tx_select),
        .chip_addr(chip_addr),

        .current_beam(),
        .done(mem_done),
        .error(mem_error)
    );

    sensor_data_acquisition sensor_acq_i (
        .clk(clk),
        .reset(~rst_n),

        .spi_start(spi_start_sensor),
        .spi_address(spi_address_sensor),
        .spi_write_data(spi_write_data_sensor),
        .spi_read_data(spi_read_data),
        .spi_complete(transaction_complete),
        .spi_read_write(spi_read_write_sensor),

        .sensor_read_request(sensor_start_req),
        .sensor_select(sensor_select),
        .continuous_mode(continuous_mode),
        .sample_period(sample_period),

        .temperature_raw(temperature_raw),
        .temperature_celsius(temperature_celsius),
        .detector_power({detector_power3, detector_power2, detector_power1, detector_power0}),
        .sensors_valid(sensors_valid),
        .conversion_complete(sensor_done),
        .active_sensor(),
        .adc_error(sensor_error)
    );

    typedef enum logic [1:0] {IDLE, WRITE_BEAMS, READ_SENSORS, DONE} top_state_t;
    top_state_t top_state, top_next;

    reg busy_reg, done_reg, error_reg;

    assign busy = busy_reg;
    assign done = done_reg;
    assign error = error_reg;

    always_comb begin
        if (mode_switch == 1'b0) begin
            start_transaction = spi_start_mem;
            spi_address       = spi_address_mem;
            spi_write_data    = spi_write_data_mem;
            spi_read_write    = spi_read_write_mem;
        end else begin
            start_transaction = spi_start_sensor;
            spi_address       = spi_address_sensor;
            spi_write_data    = spi_write_data_sensor;
            spi_read_write    = spi_read_write_sensor;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            top_state <= IDLE;
            mem_start_send <= 1'b0;
            sensor_start_req <= 1'b0;
            busy_reg <= 1'b0;
            done_reg <= 1'b0;
            error_reg <= 1'b0;
        end else begin
            top_state <= top_next;

            mem_start_send <= 1'b0;
            sensor_start_req <= 1'b0;
            done_reg <= 1'b0;
            error_reg <= 1'b0;

            case (top_state)
                IDLE: begin
                    busy_reg <= 1'b0;
                    if (start_operation) begin
                        busy_reg <= 1'b1;
                        done_reg <= 1'b0;
                        error_reg <= 1'b0;
                        if (mode_switch == 1'b0) begin
                            mem_start_send <= 1'b1;
                            top_next <= WRITE_BEAMS;
                        end else begin
                            sensor_start_req <= 1'b1;
                            top_next <= READ_SENSORS;
                        end
                    end else begin
                        top_next <= IDLE;
                    end
                end

                WRITE_BEAMS: begin
                    busy_reg <= 1'b1;
                    if (mem_done) begin
                        done_reg <= 1'b1;
                        busy_reg <= 1'b0;
                        if (mem_error) error_reg <= 1'b1;
                        top_next <= DONE;
                    end else begin
                        top_next <= WRITE_BEAMS;
                    end
                end

                READ_SENSORS: begin
                    busy_reg <= 1'b1;
                    if (sensor_done) begin
                        done_reg <= 1'b1;
                        busy_reg <= 1'b0;
                        if (sensor_error) error_reg <= 1'b1;
                        top_next <= DONE;
                    end else begin
                        top_next <= READ_SENSORS;
                    end
                end

                DONE: begin
                    if (!start_operation) begin
                        top_next <= IDLE;
                    end else begin
                        top_next <= DONE;
                    end
                end

                default: top_next <= IDLE;
            endcase
        end
    end

endmodule


//endmodule
