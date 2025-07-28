## How it works

This is a proof of concept for using latches in the sky130 node to save area compared to flipflops.
The design uses some explicit sky130 standard cells.
It includes two latches `data[1:0]` for data storage, and some components to feed them:

	clk --------------------+
	                        V
	we[0] -----------> clock_gate0
	                        V
	wdata -> n_latch -> p_latch0 (data[0])
	                \-> p_latch1 (data[1])
	                        ^
	we[1] -----------> clock_gate1
	                        ^
	clk --------------------+

The `n_latch -> p_latch` combination basically forms a flip flop, which is usually used as single standard cell (such as sky130's `dftxp` cells). For this construction as well as for a standard flip flop, the N latch propagates the input value when the clock goes low. The N latch closes when the clock goes high (keeping the current value), at which point the P latch propagates the value from the N latch. The result is that data coming into the N latch is sampled at the rising clock edge and stored in the P latch (if the P latch is clocked during that cycle).

A standard flipflop stores the same bit twice, once in each latch. For memory arrays, we should be able save some space by sharing the N latch between multiple write targets. This design is a minimal example of that, but I expect that memory arrays need to be of some size before the overhead of this setup is outweighed of the area gains per bit stored.

The clock gates are used to decide which P latches to update. Just like the N latch, the clock gate samples the incoming signal (write enable in this case) as long as the clock is low. If a write enable bit in `we[1:0]` coming into the clock gate during the previous cycle was high, `wdata` from that cycle will be written to the corresponding P latch this cycle.

## How to test
To update the latches:

- During the same cycle:
	- Set `wdata` to the value that you want to write
	- Set `we[1:0]` high for the bits that you want to update (`data[0]`, `data[1]`, or both)
- The write should be reflected in `data[1:0]` two cycles later (there is one cycle of input buffering before the write is applied)

It should be ok to change the value of `wdata` the cycle after a write, but if this corrupts the write, keep `wdata` stable one cycle after `we` has been taken low.
