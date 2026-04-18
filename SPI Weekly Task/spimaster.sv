`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/11/2025 05:12:16 PM
// Design Name: 
// Module Name: spimaster
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module spi_master_controller #(
    parameter integer SYS_CLK_FREQ = 100_000_000, 
    parameter integer SPI_CLK_FREQ = 25_000_000,  
    parameter integer TIMEOUT_CYCLES = 10000      
)(
    input  wire        clk,               
    input  wire        reset,            

    output reg         sclk,              
    output reg         csb,               
    output reg         sdio_out,          
    output reg         sdio_oe,          
    input  wire        sdi,               

    input  wire        start_transaction, 
    input  wire [15:0] address,           
    input  wire [7:0]  write_data,        
    input  wire        read_write,      
    output reg  [7:0]  read_data,         
    output reg         transaction_complete,
    output reg         transaction_error,
    output wire        spi_busy           
);

    localparam integer CLK_DIV = SYS_CLK_FREQ / (2 * SPI_CLK_FREQ); 
 
    reg [31:0] clk_div_cnt;
    reg        spi_active;
    reg [4:0]  bit_cnt;         
    reg [23:0] shift_reg;      
    reg [31:0] timeout_cnt;
    reg        prev_sclk;

    assign spi_busy = spi_active;

    wire [23:0] frame_in = {address, write_data};

    always @(posedge clk) begin
        if (reset) begin
            clk_div_cnt <= 0;
            sclk <= 1'b0; 
            prev_sclk <= 1'b0;
        end else if (spi_active) begin
            if (clk_div_cnt == (CLK_DIV - 1)) begin
                clk_div_cnt <= 0;
                sclk <= ~sclk;
            end else begin
                clk_div_cnt <= clk_div_cnt + 1;
            end
            prev_sclk <= sclk;
        end else begin
            clk_div_cnt <= 0;
            sclk <= 1'b0; 
            prev_sclk <= 1'b0;
        end
    end

    typedef enum logic [2:0] {IDLE, START, TRANSFER, FINISH, ERROR} state_t;
    state_t state, next_state;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    next_state = start_transaction ? START : IDLE;
            START:   next_state = TRANSFER;
            TRANSFER: begin
                if (transaction_error) next_state = ERROR;
                else if (spi_active == 1'b0) next_state = FINISH; 
                else next_state = TRANSFER;
            end
            FINISH:  next_state = IDLE;
            ERROR:   next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            spi_active <= 1'b0;
            csb <= 1'b1;
            sdio_out <= 1'b0;
            sdio_oe <= 1'b0;
            shift_reg <= 24'h0;
            bit_cnt <= 5'd0;
            transaction_complete <= 1'b0;
            transaction_error <= 1'b0;
            timeout_cnt <= 32'd0;
            read_data <= 8'h00;
        end else begin
            transaction_complete <= 1'b0;

            case (state)
                IDLE: begin
                    csb <= 1'b1;
                    sdio_oe <= 1'b0;
                    spi_active <= 1'b0;
                    transaction_error <= 1'b0;
                    timeout_cnt <= 0;
                end

                START: begin
                    csb <= 1'b0;                  
                    spi_active <= 1'b1;
                    shift_reg <= frame_in;       
                    bit_cnt <= 5'd23;             
                    sdio_oe <= 1'b1;            
                    sdio_out <= frame_in[23];     
                    timeout_cnt <= 0;
                end

                TRANSFER: begin
                    if (spi_active) timeout_cnt <= timeout_cnt + 1;
                    if (timeout_cnt > TIMEOUT_CYCLES) begin
                        transaction_error <= 1'b1;
                        spi_active <= 1'b0;
                        csb <= 1'b1;
                        sdio_oe <= 1'b0;
                        read_data <= 8'h00;
                    end else begin
                       
                        if (prev_sclk == 1'b0 && sclk == 1'b1) begin
                            
                            shift_reg <= {shift_reg[22:0], sdi};
                            if (bit_cnt == 0) begin
                                spi_active <= 1'b0;
                                csb <= 1'b1;
                                sdio_oe <= 1'b0;
                                read_data <= shift_reg[7:0] | (sdi ? 8'h01 : 8'h00); 
                                transaction_complete <= 1'b1;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end

                        if (prev_sclk == 1'b1 && sclk == 1'b0 && spi_active) begin
                          
                            if (bit_cnt != 0) begin
                                sdio_out <= shift_reg[bit_cnt-1];
                            end
                        end
                    end
                end

                FINISH: begin
                    transaction_complete <= 1'b0;
                    csb <= 1'b1;
                    sdio_oe <= 1'b0;
                    spi_active <= 1'b0;
                end

                ERROR: begin
                    csb <= 1'b1;
                    sdio_oe <= 1'b0;
                    spi_active <= 1'b0;
                    transaction_error <= 1'b1;
                end

                default: begin
                    csb <= 1'b1;
                    sdio_oe <= 1'b0;
                    spi_active <= 1'b0;
                end
            endcase
        end
    end

endmodule
