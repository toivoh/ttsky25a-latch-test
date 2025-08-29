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

### Alternate version: P latches only
Enabling the define `USE_P_ONLY` in `project.v` and setting `p_only = True` in test.py enables the alternate version with an FF instead of the N latch:

	clk --------------------+
	                        V
	we[0] -----------> clock_gate0
	               wdata    V
	wdata_in -> FF ---> p_latch0 (data[0])
	              \---> p_latch1 (data[1])
	                        ^
	we[1] -----------> clock_gate1
	                        ^
	clk --------------------+

If we use `wdata_in` in the same way as `wdata` was used in the version above, this version should work the same.
An FF can be seen as a N latch followed by a P latch:

	D -> FF -> Q     =     D -> n_latch -> p_latch -> Q

and two P latches in sequence should have the same timing behavior as a single P latch, if both are transparent at the same time (except for some extra delay when you have two P latches in sequence):

	      D -> FF -> p_latch -> Q          =     D -> n_latch -> p_latch -> p_latch -> Q
	=     D -> n_latch -> p_latch -> Q     =     D -> FF -> Q

The difference compared to using a single FF comes when the second P latch has a gated clock, then we can choose which P latches to write to and which ones should keep their values.
The difference compared to using the original version is that the FF can be used as a regular FF in the design, or one that already exists can be used.
Another difference to consider is that the input to the P latch must stabilize during the first half of the clock cycle (the N latch in the original design captures the incoming value at the end of the previous clock cycle instead.) Since the FF's output value stabilizes soon after the rising clock edge, this should be fine.

No hold buffering is needed between the FF and the P latch, since the output of the FF is stable throughout the whole clock cycle, and the P latch closes in the middle of the clock cycle. The output value of the P latch will be stable almost at the beginning of the clock cycle though, since the output of the FF feeding it is. There can be a short glitch at the beginning of the clock cycle.

Comparing the two figures, now suppose that `wdata` in the NP version is also fed from an FF that receives `wdata_in`. The difference now becomes that there is one cycle less delay from the data coming through `wdata_in` to the data being written to the P latches. The delay for the write enable `we` is still the same though, so it now needs to be enabled one cycle before the data that should be written to the P latch is in the FF, at the same time as the write enable for the FF is active. This can be a challenge if you don't know which write enable to raise one cycle in advance.

#### Results from hardening and test
I did some experiments with similar latch based memories in https://github.com/toivoh/tt08-on-chip-memory-test for TT08, but at that point the structure `FF -> p_latch` caused an STA violation.
This no longer seems to be the case in TT10. The connection does trigger some time borrowing if the data value coming out of the FF arrives at the P latch a bit later than the rising edge from the clock gate, in my experiment I got around 0.65 ns of time borrowing.

GL simulations recreate the expected behavior where an update value stored in the FF is reflected in the same cycle as the output of those P latches that had their write enable signal high during the previous clock cycle.
Short glitches can be seen at the P latch outputs the beginning of clock cycles where they are written at the same time as the value stored in the FF changes back to the previous value stored in the P latch.

## How to test
To update the latches:

- During the same cycle:
	- Set `wdata` to the value that you want to write
	- Set `we[1:0]` high for the bits that you want to update (`data[0]`, `data[1]`, or both)
- The write should be reflected in `data[1:0]` two cycles later (there is one cycle of input buffering before the write is applied)

It should be ok to change the value of `wdata` the cycle after a write, but if this corrupts the write, keep `wdata` stable one cycle after `we` has been taken low.

Alternate version with only P latches: Like above, but set `wdata` one cycle later (one cycle after the corresponding `we[1:0]`).
It really should be ok to change `wdata` the cycle after was sampled for a given write enable activation.
