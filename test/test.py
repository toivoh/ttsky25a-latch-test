# SPDX-FileCopyrightText: © 2025 Toivo Henningsson
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
	clock = Clock(dut.clk, 10, units="us")
	cocotb.start_soon(clock.start())

	dut.rst_n.value = 0
	dut.ui_in.value = 7
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1
	dut.ui_in.value = 0

	if False:
		for i in range(4):
			wdata = i & 1
			for j in range(5):
				we = 3 if j == 2 else 0
				ui_in = wdata | (we << 1)
				dut.ui_in.value = ui_in
				await ClockCycles(dut.clk, 1)

				data_out = dut.uo_out.value.integer
				print("ui_in = ", ui_in, ", data_out = ", data_out, sep="")

	# Use alternate version with P latches only? Otherwise use N latch -> P latch. Use together with `define USE_P_ONLY in project.v.
	p_only = True

	if True:
		# Try writing to the the first latch on even clock cycles and the second latch on odd clock cycles,
		# check that they get the values that are expected.

		wait_cycles = 1 if p_only else 2

		lfsr = 1 # use a 7-bit LFSR to generate some test patterns

		data_head = 3 # The most recently written data values
		data_pipe = -1 & ((1 << (2*wait_cycles)) - 1) # Delay pipe of previous data values

		for i in range(128+10):
			we = (i&1) + 1
			wdata = lfsr & 1
			print("we = ", we, ", wdata = ", wdata, sep="", end="\t")

			# Apply write to data_head
			we_eff = we ^ 3 if p_only else we
			data_head = (data_head & ~we_eff) | (we_eff & (wdata*3))

			# Apply write to the design
			ui_in = wdata | (we << 1)
			dut.ui_in.value = ui_in
			await ClockCycles(dut.clk, 1)

			# Read out and compare with expected data values
			data_out = dut.uo_out.value.integer
			data_expected = data_pipe & 3
			print("out = ", data_out, ", expected = ", data_expected, sep="")
			assert data_out == data_expected

			# Update LFSR and delay line
			lfsr = ((lfsr << 1) & 127) | (((lfsr&1)!=0)^((lfsr&64)!=0))
			data_pipe = (data_pipe >> 2) | (data_head << (2*(wait_cycles - 1)))
