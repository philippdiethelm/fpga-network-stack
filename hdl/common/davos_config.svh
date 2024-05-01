`ifndef DAVOS_CONFIG_SVH
`define DAVOS_CONFIG_SVH

`define USE_10G
parameter NETWORK_STACK_WIDTH = 64 * 8;

// TCP/IP
parameter TCP_STACK_EN = 1;
parameter TCP_RX_BYPASS_EN = 1;

//UDP/IP
parameter UDP_STACK_EN = 1;

//RoCEv2
parameter ROCE_STACK_EN = 0;



//DRAM
parameter NUM_DDR_CHANNELS = 2;
parameter NUM_TCP_CHANNELS = 2;
parameter NUM_NET_PORTS = 2;


`define DRAM_EN1


`ifdef DRAM_EN1
`define USE_DDR
`endif

`ifdef DRAM_EN10
`define USE_DDR
`endif

`ifdef DRAM_EN01
`define USE_DDR
`endif


`endif //DAVOS_CONFIG_SVH
