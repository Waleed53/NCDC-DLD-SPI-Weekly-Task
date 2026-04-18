`timescale 1ns / 1ps
module beam_positions_rom (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [10:0] addr,     
    output reg  [7:0]  data_out
);

    localparam integer N_BEAMS = 121;
    localparam integer BYTES_PER_BEAM = 12;
    localparam integer ROM_SIZE = N_BEAMS * BYTES_PER_BEAM;

    reg [7:0] rom [0:ROM_SIZE-1];

    reg [11:0] PHASE_LUT [0:127];
    initial begin
        PHASE_LUT[0]  = 12'h3F20; PHASE_LUT[1]  = 12'h3F21; PHASE_LUT[2]  = 12'h3F23; PHASE_LUT[3]  = 12'h3F24;
        PHASE_LUT[4]  = 12'h3F26; PHASE_LUT[5]  = 12'h3E27; PHASE_LUT[6]  = 12'h3E28; PHASE_LUT[7]  = 12'h3D2A;
        PHASE_LUT[8]  = 12'h3D2B; PHASE_LUT[9]  = 12'h3C2D; PHASE_LUT[10] = 12'h3C2E; PHASE_LUT[11] = 12'h3B2F;
        PHASE_LUT[12] = 12'h3A30; PHASE_LUT[13] = 12'h3931; PHASE_LUT[14] = 12'h3833; PHASE_LUT[15] = 12'h3734;
        PHASE_LUT[16] = 12'h3635; PHASE_LUT[17] = 12'h3536; PHASE_LUT[18] = 12'h3437; PHASE_LUT[19] = 12'h3338;
        PHASE_LUT[20] = 12'h3238; PHASE_LUT[21] = 12'h3039; PHASE_LUT[22] = 12'h2F3A; PHASE_LUT[23] = 12'h2E3A;
        PHASE_LUT[24] = 12'h2C3B; PHASE_LUT[25] = 12'h2B3C; PHASE_LUT[26] = 12'h2A3C; PHASE_LUT[27] = 12'h283C;
        PHASE_LUT[28] = 12'h273D; PHASE_LUT[29] = 12'h253D; PHASE_LUT[30] = 12'h243D; PHASE_LUT[31] = 12'h223D;
        PHASE_LUT[32] = 12'h213D; PHASE_LUT[33] = 12'h013D; PHASE_LUT[34] = 12'h033D; PHASE_LUT[35] = 12'h043D;
        PHASE_LUT[36] = 12'h063D; PHASE_LUT[37] = 12'h073C; PHASE_LUT[38] = 12'h083C; PHASE_LUT[39] = 12'h0A3C;
        PHASE_LUT[40] = 12'h0B3B; PHASE_LUT[41] = 12'h0D3A; PHASE_LUT[42] = 12'h0E3A; PHASE_LUT[43] = 12'h0F39;
        PHASE_LUT[44] = 12'h1138; PHASE_LUT[45] = 12'h1238; PHASE_LUT[46] = 12'h1337; PHASE_LUT[47] = 12'h1436;
        PHASE_LUT[48] = 12'h1635; PHASE_LUT[49] = 12'h1734; PHASE_LUT[50] = 12'h1833; PHASE_LUT[51] = 12'h1931;
        PHASE_LUT[52] = 12'h1930; PHASE_LUT[53] = 12'h1A2F; PHASE_LUT[54] = 12'h1B2E; PHASE_LUT[55] = 12'h1C2D;
        PHASE_LUT[56] = 12'h1C2B; PHASE_LUT[57] = 12'h1D2A; PHASE_LUT[58] = 12'h1E28; PHASE_LUT[59] = 12'h1E27;
        PHASE_LUT[60] = 12'h1E26; PHASE_LUT[61] = 12'h1F24; PHASE_LUT[62] = 12'h1F23; PHASE_LUT[63] = 12'h1F21;
        PHASE_LUT[64] = 12'h1F20; PHASE_LUT[65] = 12'h1F01; PHASE_LUT[66] = 12'h1F03; PHASE_LUT[67] = 12'h1F04;
        PHASE_LUT[68] = 12'h1F06; PHASE_LUT[69] = 12'h1E07; PHASE_LUT[70] = 12'h1E08; PHASE_LUT[71] = 12'h1D0A;
        PHASE_LUT[72] = 12'h1D0B; PHASE_LUT[73] = 12'h1C0D; PHASE_LUT[74] = 12'h1C0E; PHASE_LUT[75] = 12'h1B0F;
        PHASE_LUT[76] = 12'h1A10; PHASE_LUT[77] = 12'h1911; PHASE_LUT[78] = 12'h1813; PHASE_LUT[79] = 12'h1714;
        PHASE_LUT[80] = 12'h1615; PHASE_LUT[81] = 12'h1516; PHASE_LUT[82] = 12'h1417; PHASE_LUT[83] = 12'h1318;
        PHASE_LUT[84] = 12'h1218; PHASE_LUT[85] = 12'h1019; PHASE_LUT[86] = 12'h0F1A; PHASE_LUT[87] = 12'h0E1A;
        PHASE_LUT[88] = 12'h0C1B; PHASE_LUT[89] = 12'h0B1C; PHASE_LUT[90] = 12'h0A1C; PHASE_LUT[91] = 12'h081C;
        PHASE_LUT[92] = 12'h071D; PHASE_LUT[93] = 12'h051D; PHASE_LUT[94] = 12'h041D; PHASE_LUT[95] = 12'h021D;
        PHASE_LUT[96] = 12'h011D; PHASE_LUT[97] = 12'h211D; PHASE_LUT[98] = 12'h231D; PHASE_LUT[99] = 12'h241D;
        PHASE_LUT[100]= 12'h261D; PHASE_LUT[101]= 12'h271C; PHASE_LUT[102]= 12'h281C; PHASE_LUT[103]= 12'h2A1C;
        PHASE_LUT[104]= 12'h2B1B; PHASE_LUT[105]= 12'h2D1A; PHASE_LUT[106]= 12'h2E1A; PHASE_LUT[107]= 12'h2F19;
        PHASE_LUT[108]= 12'h3118; PHASE_LUT[109]= 12'h3218; PHASE_LUT[110]= 12'h3317; PHASE_LUT[111]= 12'h3416;
        PHASE_LUT[112]= 12'h3615; PHASE_LUT[113]= 12'h3714; PHASE_LUT[114]= 12'h3813; PHASE_LUT[115]= 12'h3911;
        PHASE_LUT[116]= 12'h3910; PHASE_LUT[117]= 12'h3A0F; PHASE_LUT[118]= 12'h3B0E; PHASE_LUT[119]= 12'h3C0D;
        PHASE_LUT[120]= 12'h3C0B; PHASE_LUT[121]= 12'h3D0A; PHASE_LUT[122]= 12'h3E08; PHASE_LUT[123]= 12'h3E07;
        PHASE_LUT[124]= 12'h3E06; PHASE_LUT[125]= 12'h3F04; PHASE_LUT[126]= 12'h3F03; PHASE_LUT[127]= 12'h3F01;
    end

    initial begin
        integer b, ch, param, base_idx;
        integer phase_idx;
        reg [11:0] iq;
        reg [7:0] VGA_VAL;
        VGA_VAL = 8'h7F;
        for (b = 0; b < ROM_SIZE; b = b + 1) rom[b] = 8'h00;
        for (b = 0; b < N_BEAMS; b = b + 1) begin
            for (ch = 0; ch < 4; ch = ch + 1) begin
                phase_idx = ( (b * (ch+1)) % 128 );
                iq = PHASE_LUT[phase_idx];
                base_idx = b * BYTES_PER_BEAM + ch * 3;
                rom[base_idx + 0] = VGA_VAL;
                rom[base_idx + 1] = {2'b00, iq[11:6]};
                rom[base_idx + 2] = {2'b00, iq[5:0]};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) data_out <= 8'h00;
        else data_out <= rom[addr];
    end

endmodule
