## Clock signal
set_property PACKAGE_PIN W5 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]
create_clock -period 10.000 -name CLK -waveform {0.000 5.000} [get_ports CLK]

## Buttons
set_property PACKAGE_PIN U17 [get_ports RESET]
set_property IOSTANDARD LVCMOS33 [get_ports RESET]
set_property PACKAGE_PIN T17 [get_ports BTNR]
set_property IOSTANDARD LVCMOS33 [get_ports BTNR]
#    set_input_delay -clock [get_clocks CLK] -min -add_delay 0.700 [get_ports RESET]
#    set_input_delay -clock [get_clocks CLK] -max -add_delay 5.500 [get_ports RESET]

## LEDs
set_property PACKAGE_PIN U16 [get_ports LD0]
set_property IOSTANDARD LVCMOS33 [get_ports LD0]
set_property PACKAGE_PIN E19 [get_ports LD1]
set_property IOSTANDARD LVCMOS33 [get_ports LD1]
set_property PACKAGE_PIN U19 [get_ports LD2]
set_property IOSTANDARD LVCMOS33 [get_ports LD2]

## Display 7 segments
set_property PACKAGE_PIN W7 [get_ports {Hex[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[0]}]
set_property PACKAGE_PIN W6 [get_ports {Hex[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[1]}]
set_property PACKAGE_PIN U8 [get_ports {Hex[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[2]}]
set_property PACKAGE_PIN V8 [get_ports {Hex[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[3]}]
set_property PACKAGE_PIN U5 [get_ports {Hex[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[4]}]
set_property PACKAGE_PIN V5 [get_ports {Hex[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[5]}]
set_property PACKAGE_PIN U7 [get_ports {Hex[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[6]}]
set_property PACKAGE_PIN V7 [get_ports {Hex[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex[7]}]
set_property PACKAGE_PIN U2 [get_ports {Hex_select[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex_select[0]}]
set_property PACKAGE_PIN U4 [get_ports {Hex_select[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex_select[1]}]
set_property PACKAGE_PIN V4 [get_ports {Hex_select[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex_select[2]}]
set_property PACKAGE_PIN W4 [get_ports {Hex_select[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Hex_select[3]}]

## USB-UART
set_property PACKAGE_PIN B18 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN A18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

set_property PACKAGE_PIN W18 [get_ports {comm_ctrl_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {comm_ctrl_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {comm_ctrl_state[0]}]

set_property PACKAGE_PIN V19 [get_ports {comm_ctrl_state[0]}]
