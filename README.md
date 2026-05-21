The modules `red_pitaya_top.sv`, `FIR.sv`, and `MAC.sv` can be implemented into the standard Red Pitaya design (v0.94). They can be found in the `rtl/` directory.
The `red_pitaya_top.sv` module replaces the top module in the standard design. 
It connects the ADC and DAC to the FIR module in the section:  
```systemverilog
///////////////
// FIR
///////////////
``` 

The connection to the bus is done in the section:  
```systemverilog
////////////////////////////////////////////////////////////////////////////////
// system bus decoder & multiplexer (it breaks memory addresses into 8 regions) 
////////////////////////////////////////////////////////////////////////////////
```  

The FIR filter computation is done in the `FIR.sv` module, using the `MAC.sv` module.

The Python scripts used for writing and reading the coefficients can be found in the  `scripts/` directory. `.txt` files containing the coefficients can be uploaded to the Red Pitaya Linux from a computer. `load_coeff.py` can be used to write the coefficients into the right address. The `.txt` file needs to have the following form:  
TAP 00   ADDR 000   VALUE 4096  
TAP 00   ADDR 001   VALUE -1  
TAP 00   ADDR 002   VALUE -1

`read_coeff.py` can be used to read single coefficients at a specified address.
