/*
 * Copyright (c) 2025 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Use alternate version with P latches only? Otherwise use N latch -> P latch
`define USE_P_ONLY


// Two bits of memory stored in P-latches, with shared N-latch for writing
module tt_um_example (
		input  wire [7:0] ui_in,    // Dedicated inputs
		output wire [7:0] uo_out,   // Dedicated outputs
		input  wire [7:0] uio_in,   // IOs: Input path
		output wire [7:0] uio_out,  // IOs: Output path
		output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // always 1 when the design is powered, so you can ignore it
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	// Register input
	reg [7:0] in;
	always @(posedge clk) in <= ui_in;

	// Unpack input
	wire wdata;
	wire [1:0] we;
	assign {we, wdata} = in;


`ifdef PURE_RTL
	wire wdata_eff;
`ifdef USE_P_ONLY
	assign wdata_eff = ui_in[0]; // look at the next wdata bit instead since we have one cycle less delay
`else
	assign wdata_eff = wdata;
`endif
	reg [1:0] data;
	always @(posedge clk) begin
		if (we[0]) data[0] <= wdata_eff;
		if (we[1]) data[1] <= wdata_eff;
	end
`else
`ifdef USE_P_ONLY
	wire wdata2 = wdata;
`else
	// Shared negative edge triggered latch
	wire wdata2;
	sky130_fd_sc_hd__dlxtn_1 n_latch( .GATE_N(clk), .D(wdata), .Q(wdata2));
`endif

	// Clock gates
	wire [1:0] gclk;
	sky130_fd_sc_hd__dlclkp_1 clock_gate0(.CLK(clk), .GATE(we[0]), .GCLK(gclk[0]));
	sky130_fd_sc_hd__dlclkp_1 clock_gate1(.CLK(clk), .GATE(we[1]), .GCLK(gclk[1]));

	wire [1:0] data;
	sky130_fd_sc_hd__dlxtp_1 p_latch0(.GATE(gclk[0]), .D(wdata2), .Q(data[0]));
	sky130_fd_sc_hd__dlxtp_1 p_latch1(.GATE(gclk[1]), .D(wdata2), .Q(data[1]));
`endif


	assign uo_out = data;
	assign uio_out = 0;
	assign uio_oe  = 0;

	wire _unused = &{ena, rst_n, ui_in, uio_in, 1'b0};
endmodule
