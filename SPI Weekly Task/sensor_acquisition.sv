module sensor_data_acquisition (
    input  wire        clk,
    input  wire        reset,

    output reg  [15:0] spi_address,
    output reg  [7:0]  spi_write_data,
    input  wire [7:0]  spi_read_data,
    output reg         spi_start,
    input  wire        spi_complete,
    output reg         spi_read_write,  

    input  wire        sensor_read_request, 
    input  wire [2:0]  sensor_select,      
    input  wire        continuous_mode,
    input  wire [7:0]  sample_period,

    output reg  [7:0]  temperature_raw,
    output reg  signed [7:0] temperature_celsius,
    output reg  [31:0] detector_power,   
    output reg         sensors_valid,
    output reg         conversion_complete,
    output reg  [2:0]  active_sensor,
    output reg         adc_error
);

    localparam REG_DET_ENABLE = 16'h0030;
    localparam REG_ADC_CTRL   = 16'h0032;
    localparam REG_ADC_OUT    = 16'h0033;

    localparam ADC_EOC_BIT     = 0;
    localparam MUX_SEL_SHIFT   = 1;
    localparam ST_CONV_BIT     = 4;
    localparam CLK_EN_BIT      = 5;
    localparam ADC_EN_BIT      = 6;
    localparam ADC_CLKFREQ_BIT = 7;

    localparam [7:0] ADC_INIT_VALUE   = (1 << ADC_EN_BIT) | (1 << CLK_EN_BIT) | (0 << ADC_CLKFREQ_BIT);
    localparam [7:0] START_CONV_VALUE = ADC_INIT_VALUE | (1 << ST_CONV_BIT);

    localparam signed [7:0] TEMP_REF_CODE     = 8'd145;
    localparam integer       NUM              = 10;  
    localparam integer       DEN              = 8;
    localparam signed [7:0] TEMP_REF_CELSIUS = 8'd25;

    typedef enum logic [3:0] {
        S_IDLE,
        S_ENABLE_DET,
        S_CONFIG_ADC,
        S_SELECT_MUX,
        S_START_CONV,
        S_WAIT_CONV,
        S_READ_RESULT,
        S_PROCESS,
        S_NEXT_SENSOR,
        S_COMPLETE
    } state_t;

    state_t state;
    reg [2:0] current_sensor;
    reg [2:0] total_sensors;
    reg [15:0] conv_timeout;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state               <= S_IDLE;
            spi_start           <= 1'b0;
            sensors_valid       <= 1'b0;
            conversion_complete <= 1'b0;
            adc_error           <= 1'b0;
            current_sensor      <= 0;
            total_sensors       <= 0;
            conv_timeout        <= 0;
            detector_power      <= 32'd0;
            temperature_raw     <= 8'd0;
            temperature_celsius <= 8'd0;
            active_sensor       <= 3'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    sensors_valid       <= 1'b0;
                    conversion_complete <= 1'b0;
                    spi_start           <= 1'b0;
                    adc_error           <= 1'b0;
                    if (sensor_read_request) begin
                        if (sensor_select == 3'd5) begin
                            current_sensor <= 0;
                            total_sensors  <= 5; 
                        end else begin
                            current_sensor <= sensor_select;
                            total_sensors  <= 1;
                        end
                        state <= S_ENABLE_DET;
                    end
                end

                S_ENABLE_DET: begin
                    spi_address     <= REG_DET_ENABLE;
                    spi_write_data  <= 8'h0F; 
                    spi_read_write  <= 1'b0;  
                    spi_start       <= 1'b1;
                    state           <= S_CONFIG_ADC;
                end

                S_CONFIG_ADC: begin
                    spi_start <= 1'b0;
                    if (spi_complete) begin
                        spi_address     <= REG_ADC_CTRL;
                        spi_write_data  <= ADC_INIT_VALUE;
                        spi_read_write  <= 1'b0;
                        spi_start       <= 1'b1;
                        state           <= S_SELECT_MUX;
                    end
                end

                S_SELECT_MUX: begin
                    spi_start <= 1'b0;
                    if (spi_complete) begin
                        spi_address     <= REG_ADC_CTRL;
                        spi_write_data  <= ADC_INIT_VALUE | (current_sensor << MUX_SEL_SHIFT);
                        spi_read_write  <= 1'b0;
                        spi_start       <= 1'b1;
                        state           <= S_START_CONV;
                    end
                end

                S_START_CONV: begin
                    spi_start <= 1'b0;
                    if (spi_complete) begin
                        spi_address     <= REG_ADC_CTRL;
                        spi_write_data  <= (ADC_INIT_VALUE | (current_sensor << MUX_SEL_SHIFT)) | (1 << ST_CONV_BIT);
                        spi_read_write  <= 1'b0;
                        spi_start       <= 1'b1;
                        conv_timeout    <= 0;
                        state           <= S_WAIT_CONV;
                    end
                end

                S_WAIT_CONV: begin
                    spi_start <= 1'b0;
                    conv_timeout <= conv_timeout + 1;
                    if (conv_timeout > 1000) begin
                        adc_error <= 1'b1;
                        state     <= S_COMPLETE;
                    end else if (spi_complete) begin
                        spi_address     <= REG_ADC_OUT;
                        spi_read_write  <= 1'b1;
                        spi_start       <= 1'b1;
                        state           <= S_READ_RESULT;
                    end
                end

                S_READ_RESULT: begin
                    spi_start <= 1'b0;
                    if (spi_complete) begin
                        if (current_sensor == 0) begin
                            temperature_raw <= spi_read_data;
                        end else begin
                            case (current_sensor)
                                1: detector_power[7:0]    <= spi_read_data;
                                2: detector_power[15:8]   <= spi_read_data;
                                3: detector_power[23:16]  <= spi_read_data;
                                4: detector_power[31:24]  <= spi_read_data;
                            endcase
                        end
                        state <= S_PROCESS;
                    end
                end

                S_PROCESS: begin
                    if (current_sensor == 0) begin
                        logic signed [8:0] diff;
                        logic signed [15:0] scaled;
                        diff   = $signed(temperature_raw) - TEMP_REF_CODE;
                        scaled = diff * NUM;
                        temperature_celsius = (scaled / DEN) + TEMP_REF_CELSIUS;
                    end
                    state <= S_NEXT_SENSOR;
                end

                S_NEXT_SENSOR: begin
                    if (total_sensors > 1 && current_sensor < total_sensors - 1) begin
                        current_sensor <= current_sensor + 1;
                        state <= S_SELECT_MUX;
                    end else begin
                        sensors_valid       <= 1'b1;
                        conversion_complete <= 1'b1;
                        state <= S_COMPLETE;
                    end
                end

                S_COMPLETE: begin
                    if (!sensor_read_request)
                        state <= S_IDLE;
                end
            endcase
        end
    end
endmodule



