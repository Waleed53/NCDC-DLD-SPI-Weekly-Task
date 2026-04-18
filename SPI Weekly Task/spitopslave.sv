`timescale 1ns/1ps

module adar1000_spi_slave_mock (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] spi_address,
    input  wire [7:0]  spi_write_data,
    output reg  [7:0]  spi_read_data,
    input  wire        spi_start,
    output reg         spi_complete,
    input  wire        spi_read_write
);
    localparam REG_DET_ENABLE = 16'h0030;
    localparam REG_ADC_CTRL   = 16'h0032;
    localparam REG_ADC_OUT    = 16'h0033;

    localparam ST_CONV_BIT = 4;

    reg [7:0] adar_regs [0:255];
    reg       converting;
    integer   conv_delay_cnt;

    integer i;
    initial begin
        for (i=0; i<256; i=i+1) adar_regs[i] = 8'h00;
        adar_regs[REG_ADC_CTRL] = 8'h00;
        adar_regs[REG_DET_ENABLE] = 8'h00;
        adar_regs[REG_ADC_OUT] = 8'h00;
        converting = 0;
        conv_delay_cnt = 0;
        spi_read_data = 0;
        spi_complete = 0;
    end
                        reg [2:0] mux_val;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            spi_complete <= 0;
            spi_read_data <= 0;
            converting <= 0;
            conv_delay_cnt <= 0;
        end else begin
            spi_complete <= 0;

            if (spi_start) begin
                if (!spi_read_write) begin
                    adar_regs[spi_address] <= spi_write_data;
                    if (spi_address == REG_ADC_CTRL && spi_write_data[ST_CONV_BIT]) begin
                        converting <= 1;
                        conv_delay_cnt <= 0;
                    end
                    spi_complete <= 1;
                end else begin
                    if (spi_address == REG_ADC_OUT) begin
                        spi_read_data <= adar_regs[REG_ADC_OUT];
                    end else begin
                        spi_read_data <= adar_regs[spi_address];
                    end
                    spi_complete <= 1;
                end
            end

            if (converting) begin
                conv_delay_cnt <= conv_delay_cnt + 1;
                if (conv_delay_cnt == 5) begin
                    converting <= 0;
                    
                    mux_val = (adar_regs[REG_ADC_CTRL] >> 1) & 3'b111;
                    if (mux_val == 3'd0)
                        adar_regs[REG_ADC_OUT] <= 8'd145; 
                    else if (mux_val >= 3'd1 && mux_val <= 3'd4)
                        adar_regs[REG_ADC_OUT] <= 8'd60 + ((mux_val - 1) * 3);
                    else
                        adar_regs[REG_ADC_OUT] <= 8'd0;
                end
            end
        end
    end
endmodule
