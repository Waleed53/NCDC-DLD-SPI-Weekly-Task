`timescale 1ns / 1ps
module memory_data_manager_write #(
    parameter integer LOAD_PULSE_CYCLES = 40
)(
    input  wire        clk,
    input  wire        rst_n,

    output reg         start_transaction,    
    output reg  [15:0] address,              
    output reg  [7:0]  write_data,         
    output reg         read_write,           
    input  wire        transaction_complete, 
    input  wire        spi_busy,             

    output reg         tx_load,
    output reg         rx_load,

    input  wire        start_send,       
    input  wire [6:0]  beam_index_in,    
    input  wire        sequential_mode,
    input  wire [6:0]  seq_start,
    input  wire [6:0]  seq_end,
    input  wire        tx_select,         
    input  wire [1:0]  chip_addr,        

    output reg  [6:0]  current_beam,
    output reg         done,
    output reg         error
);

    localparam N_BEAMS = 121;
    localparam BYTES_PER_BEAM = 12;

    wire [10:0] rom_addr;
    wire [7:0] rom_data;

    beam_positions_rom rom_i (
        .clk(clk),
        .rst_n(rst_n),
        .addr(rom_addr),
        .data_out(rom_data)
    );

    typedef enum logic [2:0] {IDLE, ISSUE, WAIT, PULSE_LOAD, COMPLETE} state_t;
    state_t state;

    reg [3:0] fetch_counter; 
    reg [6:0] active_beam;
    reg [31:0] load_timer;
    reg seq_active;

    function automatic [15:0] build_ram_addr;
        input [1:0] chip;
        input        tx_rx;
        input [6:0] beam;
        input [3:0] idx; 
        reg [1:0] chan;
        reg [1:0] param;
        reg [15:0] addr;
        begin
            chan = idx / 3;
            param = idx % 3;
            addr = 16'h0000;
            addr[14:13] = chip;
            addr[12]    = 1'b1;   
            addr[11]    = tx_rx;
            addr[10:4]  = beam;
            addr[3:2]   = chan;
            addr[1:0]   = param;
            build_ram_addr = addr;
        end
    endfunction

    assign rom_addr = active_beam * BYTES_PER_BEAM + fetch_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fetch_counter <= 0;
            active_beam <= 0;
            start_transaction <= 1'b0;
            address <= 16'h0000;
            write_data <= 8'h00;
            read_write <= 1'b0;
            tx_load <= 1'b0;
            rx_load <= 1'b0;
            load_timer <= 0;
            current_beam <= 0;
            done <= 1'b0;
            error <= 1'b0;
            seq_active <= 1'b0;
        end else begin
            start_transaction <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_send) begin
                        seq_active <= sequential_mode;
                        if (sequential_mode) active_beam <= seq_start; else active_beam <= beam_index_in;
                        fetch_counter <= 4'd0;
                        address <= build_ram_addr(chip_addr, tx_select, active_beam, 0);
                        write_data <= rom_data;
                        read_write <= 1'b0; 
                        start_transaction <= 1'b1;
                        state <= WAIT;
                    end
                end

                WAIT: begin
                    if (transaction_complete) begin
                        if (fetch_counter == (BYTES_PER_BEAM - 1)) begin
                            current_beam <= active_beam;
                            load_timer <= 0;
                            state <= PULSE_LOAD;
                        end else begin
                            fetch_counter <= fetch_counter + 1;
                            address <= build_ram_addr(chip_addr, tx_select, active_beam, fetch_counter + 1);
                            write_data <= rom_data; 
                            start_transaction <= 1'b1;
                            state <= WAIT;
                        end
                    end
                end

                PULSE_LOAD: begin
                    load_timer <= load_timer + 1;
                    if (tx_select) tx_load <= 1'b1; else rx_load <= 1'b1;
                    if (load_timer >= LOAD_PULSE_CYCLES) begin
                        tx_load <= 1'b0; rx_load <= 1'b0;
                        done <= 1'b1;
                        if (seq_active) begin
                            if (active_beam >= seq_end) active_beam <= seq_start; else active_beam <= active_beam + 1;
                            fetch_counter <= 0;
                            address <= build_ram_addr(chip_addr, tx_select, active_beam, 0);
                            write_data <= rom_data;
                            start_transaction <= 1'b1;
                            state <= WAIT;
                        end else begin
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
