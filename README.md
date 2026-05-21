The modules red_pitaya_top.sv, FIR.sv and MAC.sv can be implemented into the standart Red Pitaya design (v0.94). 

The red_pitaya_top.sv module replaces the top module in the standard design. 

It connects the ADC and DAC to the FIR module, under:

///////////////
// FIR
///////////////

The connection to the bus is done under:

////////////////////////////////////////////////////////////////////////////////
// system bus decoder & multiplexer (it breaks memory addresses into 8 regions) 
////////////////////////////////////////////////////////////////////////////////

The FIR filter calculation is done in the FIR.sv module, using the MAC.sv module.

