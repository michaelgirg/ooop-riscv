# The RTL-only synthesis target has no board-level pin assignments yet, but it
# still needs a clock requirement so Vivado can analyze register-to-register
# timing. A 10 ns period requests a 100 MHz clock.
create_clock -period 10.000 -name sys_clk [get_ports clk_i]

# Input/output delays and pin locations belong in the future board wrapper,
# where the external device and board timing are known.
