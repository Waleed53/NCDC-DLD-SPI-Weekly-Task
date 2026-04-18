
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
    localparam EOC_BIT    = 0;

    reg [7:0] adar_regs [0:255];

    reg        spi_pending;
    reg [15:0] addr_buf;
    reg [7:0]  data_buf;
    reg        rw_buf;

    reg        converting;
    integer    conv_delay_cnt;
    integer    ADC_DELAY_CYCLES = 6;

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            adar_regs[i] = 8'h00;
        converting = 1'b0;
        conv_delay_cnt = 0;
        spi_pending = 1'b0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 256; i = i + 1)
                adar_regs[i] <= 8'h00;
            spi_complete   <= 1'b0;
            spi_read_data  <= 8'h00;
            spi_pending    <= 1'b0;
            converting     <= 1'b0;
            conv_delay_cnt <= 0;
            addr_buf       <= 16'h0000;
            data_buf       <= 8'h00;
            rw_buf         <= 1'b0;
        end else begin
            spi_complete <= 1'b0;

            if (spi_start && !spi_pending) begin
                spi_pending <= 1'b1;
                addr_buf    <= spi_address;
                data_buf    <= spi_write_data;
                rw_buf      <= spi_read_write;
            end

            if (spi_pending) begin
                if (rw_buf == 1'b0) begin
                    adar_regs[addr_buf] <= data_buf;

                    if (addr_buf == REG_ADC_CTRL && data_buf[ST_CONV_BIT]) begin
                        converting <= 1'b1;
                        conv_delay_cnt <= 0;
                        adar_regs[REG_ADC_CTRL][EOC_BIT] <= 1'b0;
                    end
                end else begin
                    spi_read_data <= adar_regs[addr_buf];
                end

                spi_complete <= 1'b1;
                spi_pending <= 1'b0;
            end

            if (converting) begin
                conv_delay_cnt <= conv_delay_cnt + 1;
                if (conv_delay_cnt >= ADC_DELAY_CYCLES) begin

                    reg [2:0] mux;
                    mux = (adar_regs[REG_ADC_CTRL] >> 1) & 3'b111;

                    if (mux == 3'd0) begin
                        adar_regs[REG_ADC_OUT] <= 8'd145;
                    end else if (mux >= 3'd1 && mux <= 3'd4) begin

                        adar_regs[REG_ADC_OUT] <= (8'd60 + ((mux - 1) * 3));
                    end else begin
                        adar_regs[REG_ADC_OUT] <= 8'd0;
                    end

                    adar_regs[REG_ADC_CTRL][EOC_BIT] <= 1'b1;
                    adar_regs[REG_ADC_CTRL][ST_CONV_BIT] <= 1'b0;

                    converting <= 1'b0;
                    conv_delay_cnt <= 0;
                end
            end
        end
    end
endmodule
