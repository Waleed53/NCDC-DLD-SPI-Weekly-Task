`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/11/2025 05:54:41 PM
// Design Name: 
// Module Name: spi_slavemock
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


`timescale 1ns / 1ps
module spi_slave_mock (
    input  wire        sclk,       
    input  wire        csb,       
    input  wire        sdio_out,   
    input  wire        sdio_oe,    
    output reg         sdi,        
    output reg  [23:0] last_frame, 
    output reg  [15:0] last_addr,
    output reg  [7:0]  last_data
);

    reg [23:0] shift_in;
    reg [4:0]  bit_cnt; 
    reg        csb_d;

    reg [7:0] adar_mem [0:65535];
    integer i;
    initial begin
        for (i=0;i<65536;i=i+1) adar_mem[i] = 8'h00;
        sdi = 1'b0;
        shift_in = 24'h0;
        bit_cnt = 0;
        last_frame = 24'h0;
        last_addr = 16'h0;
        last_data = 8'h0;
    end

    always @(negedge sclk or posedge sclk) begin
    end

    always @(posedge sclk) begin
        if (csb == 0) begin
            shift_in <= {shift_in[22:0], sdio_out};
            bit_cnt <= bit_cnt + 1;
        end
    end

    reg [23:0] shift_out;
    always @(negedge sclk) begin
        if (csb == 0) begin
            sdi <= shift_out[23];
            shift_out <= {shift_out[22:0], 1'b0};
        end
    end

    reg csb_prev;
    always @(posedge sclk or negedge csb) begin
    end

    always @(posedge csb or negedge csb) begin
        if (csb == 1'b1) begin
            if (bit_cnt != 0) begin
                last_frame <= shift_in;
                last_addr <= shift_in[23:8];
                last_data <= shift_in[7:0];
              
                adar_mem[shift_in[23:8]] <= shift_in[7:0];
            end
            bit_cnt <= 0;
            shift_in <= 24'h0;
            shift_out <= 24'h0;
            sdi <= 1'b0;
        end else begin
            bit_cnt <= 0;
            shift_in <= 24'h0;
            shift_out <= 24'h0;
            sdi <= 1'b0;
        end
    end

    function [7:0] read_adar_mem;
        input [15:0] addr;
        begin
            read_adar_mem = adar_mem[addr];
        end
    endfunction

    task write_adar_mem;
        input [15:0] addr;
        input [7:0] data;
        begin
            adar_mem[addr] = data;
        end
    endtask

endmodule
