`timescale 1ns / 1ps `default_nettype none

`include "davos_config.svh"
`include "davos_types.svh"

`define USE_DDR
`define ECHO_SERVER
//`define IPERF_CLIENT
`define UDP


module tcp_ip_top (
    input  wire gt_rxp_in,
    input  wire gt_rxn_in,
    output wire gt_txp_out,
    output wire gt_txn_out,

    output wire rx_gt_locked_led,     // Indicates GT LOCK
    output wire rx_block_lock_led,    // Indicates Core Block Lock
    output wire [4:0] completion_status,

    input wire sys_reset,
    input wire gt_refclk_p,
    input wire gt_refclk_n,
    input wire dclk_p,
    input wire dclk_n,

    //156.25MHz user clock
    //input wire             uclk_p,
    //input wire             uclk_n,

`ifdef USE_DDR
    //DDR0
    input  wire        c0_sys_clk_p,
    input  wire        c0_sys_clk_n,
    output wire        c0_ddr4_act_n,
    output wire [16:0] c0_ddr4_adr,
    output wire [ 1:0] c0_ddr4_ba,
    output wire [ 0:0] c0_ddr4_bg,
    output wire [ 0:0] c0_ddr4_cke,
    output wire [ 0:0] c0_ddr4_odt,
    output wire [ 0:0] c0_ddr4_cs_n,
    output wire [ 0:0] c0_ddr4_ck_t,
    output wire [ 0:0] c0_ddr4_ck_c,
    output wire        c0_ddr4_reset_n,
    inout  wire [ 8:0] c0_ddr4_dm_dbi_n,
    inout  wire [71:0] c0_ddr4_dq,
    inout  wire [ 8:0] c0_ddr4_dqs_t,
    inout  wire [ 8:0] c0_ddr4_dqs_c,

    //DDR1
    input  wire        c1_sys_clk_p,
    input  wire        c1_sys_clk_n,
    output wire        c1_ddr4_act_n,
    output wire [16:0] c1_ddr4_adr,
    output wire [ 1:0] c1_ddr4_ba,
    output wire [ 0:0] c1_ddr4_bg,
    output wire [ 0:0] c1_ddr4_cke,
    output wire [ 0:0] c1_ddr4_odt,
    output wire [ 0:0] c1_ddr4_cs_n,
    output wire [ 0:0] c1_ddr4_ck_t,
    output wire [ 0:0] c1_ddr4_ck_c,
    output wire        c1_ddr4_reset_n,
    inout  wire [ 8:0] c1_ddr4_dm_dbi_n,
    inout  wire [71:0] c1_ddr4_dq,
    inout  wire [ 8:0] c1_ddr4_dqs_t,
    inout  wire [ 8:0] c1_ddr4_dqs_c,
`endif

    //buttons
    input wire button_center,
    input wire button_north,
    input wire button_west,
    input wire button_south,
    input wire button_east,

    input wire [3:0] gpio_switch
);

  wire aclk;
  wire aresetn;
  wire network_init;

  wire [2:0] gt_loopback_in_0;
  wire [3:0] user_rx_reset;
  wire [3:0] user_tx_reset;
  wire gtpowergood_out;

  //// For other GT loopback options please change the value appropriately
  //// For example, for internal loopback gt_loopback_in[2:0] = 3'b010;
  //// For more information and settings on loopback, refer GT Transceivers user guide

  wire dclk;
  IBUFDS #(
      .DQS_BIAS("FALSE")  // (FALSE, TRUE)
  ) dclk_BUFG_inst (
      .O (dclk),    // 1-bit output: Buffer output
      .I (dclk_p),  // 1-bit input: Diff_p buffer input (connect directly to top-level port)
      .IB(dclk_n)   // 1-bit input: Diff_n buffer input (connect directly to top-level port)
  );

  /*wire uclk;
     IBUFDS #(
     .DQS_BIAS("FALSE")  // (FALSE, TRUE)
  )
  uclk_BUFG_inst (
     .O(uclk),   // 1-bit output: Buffer output
     .I(uclk_p),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
     .IB(uclk_n)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
  );*/

  BUFG bufg_aresetn (
      .I(network_init),
      .O(aresetn)
  );


  wire [4:0] completion_status_0;
  assign completion_status = 0;

  assign rx_block_lock_led = gtpowergood_out;
  assign rx_gt_locked_led  = network_init;

  /*
 * Network Signals
 */
  axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_net_rx_data ();
  axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_net_tx_data ();

  /*
 * Application Signals
 */
  // listen&close port
  // open&close connection
  axis_meta #(.WIDTH(16)) axis_listen_port ();
  axis_meta #(.WIDTH(8)) axis_listen_port_status ();
  // notifications and pkg fetching
  axis_meta #(.WIDTH(88)) axis_notifications ();
  axis_meta #(.WIDTH(32)) axis_read_package ();
  // open&close connection
  axis_meta #(.WIDTH(48)) axis_open_connection ();
  axis_meta #(.WIDTH(24)) axis_open_status ();
  axis_meta #(.WIDTH(16)) axis_close_connection ();
  // rx data
  axis_meta #(.WIDTH(16)) axis_rx_metadata ();
  axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_rx_data ();
  // tx data
  axis_meta #(.WIDTH(32)) axis_tx_metadata ();
  axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_tx_data ();
  axis_meta #(.WIDTH(32)) axis_tx_status ();

  // //TCP/IP DDR interface
  axis_mem_cmd    axis_tcp_mem_read_cmd[NUM_TCP_CHANNELS]();
  axi_stream      axis_tcp_mem_read_data[NUM_TCP_CHANNELS]();
  axis_mem_status axis_tcp_mem_read_status[NUM_TCP_CHANNELS](); 
  
  axis_mem_cmd    axis_tcp_mem_write_cmd[NUM_TCP_CHANNELS]();
  axi_stream      axis_tcp_mem_write_data[NUM_TCP_CHANNELS]();
  axis_mem_status axis_tcp_mem_write_status[NUM_TCP_CHANNELS]();

  /*
 * UDP signals
 */
`ifdef UDP
  axis_meta #(.WIDTH(176)) axis_rx_udp_metadata ();
  axis_meta #(.WIDTH(176)) axis_tx_udp_metadata ();

  axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_rx_udp_data ();
  axi_stream #(.WIDTH(NETWORK_STACK_WIDTH)) axis_tx_udp_data ();
`endif

  network_module network_module_inst (
      .dclk(dclk),
      .net_clk(aclk),
      .sys_reset(sys_reset),
      .aresetn(aresetn),
      .network_init_done(network_init),

      .gt_refclk_p(gt_refclk_p),
      .gt_refclk_n(gt_refclk_n),

      .gt_rxp_in (gt_rxp_in),
      .gt_rxn_in (gt_rxn_in),
      .gt_txp_out(gt_txp_out),
      .gt_txn_out(gt_txn_out),

      .user_rx_reset  (user_rx_reset),
      .user_tx_reset  (user_tx_reset),
      .gtpowergood_out(gtpowergood_out),

      //master 0
      .m_axis_0_tvalid(axis_net_rx_data.valid),
      .m_axis_0_tready(axis_net_rx_data.ready),
      .m_axis_0_tdata (axis_net_rx_data.data),
      .m_axis_0_tkeep (axis_net_rx_data.keep),
      .m_axis_0_tlast (axis_net_rx_data.last),

      //slave 0
      .s_axis_0_tvalid(axis_net_tx_data.valid),
      .s_axis_0_tready(axis_net_tx_data.ready),
      .s_axis_0_tdata (axis_net_tx_data.data),
      .s_axis_0_tkeep (axis_net_tx_data.keep),
      .s_axis_0_tlast (axis_net_tx_data.last)
  );




  /*
 * TCP/IP Wrapper Module
 */
  reg [31:0] local_ip_address;
  reg [31:0] target_ip_address;

  always @(posedge aclk) begin
    local_ip_address  <= 32'hD1D4010A;  //0x0A01D4D1 -> 10.1.212.209
    target_ip_address <= {24'h0AD401, 8'h0A + gpio_switch[3]};  // 10.1.212.10
  end


  network_stack #(
      .IP_SUBNET_MASK    (32'h00FFFFFF),  //reverse
      .IP_DEFAULT_GATEWAY(32'h01D4010A),  //reverse //TODO fix this
`ifdef UDP
      .UDP_EN            (1)
`endif
  ) network_stack_inst (
      .net_clk     (aclk),
      .net_aresetn (aresetn),

      // Streams from/to Network interface
      .m_axis_net(axis_net_tx_data),
      .s_axis_net(axis_net_rx_data),
      
       //TCP/IP Interface
       // memory cmd streams
       .m_axis_read_cmd(axis_tcp_mem_read_cmd),
       .m_axis_write_cmd(axis_tcp_mem_write_cmd),
       // memory sts streams
       .s_axis_read_sts(axis_tcp_mem_read_status),
       .s_axis_write_sts(axis_tcp_mem_write_status),
       // memory data streams
       .s_axis_read_data(axis_tcp_mem_read_data),
       .m_axis_write_data(axis_tcp_mem_write_data),

      //application interface streams
      .m_axis_listen_port_status(axis_listen_port_status),
      .m_axis_notifications     (axis_notifications),
      .m_axis_open_status       (axis_open_status),
      .m_axis_rx_data           (axis_rx_data),
      .m_axis_rx_metadata       (axis_rx_metadata),
      .m_axis_tx_status         (axis_tx_status),
      .s_axis_listen_port       (axis_listen_port),
      .s_axis_close_connection  (axis_close_connection),
      .s_axis_open_connection   (axis_open_connection),
      .s_axis_read_package      (axis_read_package),
      .s_axis_tx_data           (axis_tx_data),
      .s_axis_tx_metadata       (axis_tx_metadata),

`ifdef UDP
      //UDP interface
      //RX
      .m_axis_udp_rx_metadata   (axis_rx_udp_metadata),
      .m_axis_udp_rx_data       (axis_rx_udp_data),
      //TX
      .s_axis_udp_tx_metadata   (axis_tx_udp_metadata),
      .s_axis_udp_tx_data       (axis_tx_udp_data),
`endif

      .set_ip_addr_valid(0),
      .set_ip_addr_data            (local_ip_address),
      .set_board_number_valid(0),
      .set_board_number_data ({1'b0, gpio_switch[2:0]})
  );


  /*
 * Application Module
 */
`ifdef ECHO_SERVER
  echo_server_application_ip echo_server (
      .m_axis_close_connection_TVALID(axis_close_connection.valid),      // output wire m_axis_close_connection_TVALID
      .m_axis_close_connection_TREADY(axis_close_connection.ready),      // input wire m_axis_close_connection_TREADY
      .m_axis_close_connection_TDATA(axis_close_connection.data),        // output wire [15 : 0] m_axis_close_connection_TDATA
      .m_axis_listen_port_TVALID(axis_listen_port.valid),  // output wire m_axis_listen_port_TVALID
      .m_axis_listen_port_TREADY(axis_listen_port.ready),  // input wire m_axis_listen_port_TREADY
      .m_axis_listen_port_TDATA(axis_listen_port.data),                  // output wire [15 : 0] m_axis_listen_port_TDATA
      .m_axis_open_connection_TVALID(axis_open_connection.valid),        // output wire m_axis_open_connection_TVALID
      .m_axis_open_connection_TREADY(axis_open_connection.ready),        // input wire m_axis_open_connection_TREADY
      .m_axis_open_connection_TDATA(axis_open_connection.data),          // output wire [47 : 0] m_axis_open_connection_TDATA
      .m_axis_read_package_TVALID(axis_read_package.valid),              // output wire m_axis_read_package_TVALID
      .m_axis_read_package_TREADY(axis_read_package.ready),              // input wire m_axis_read_package_TREADY
      .m_axis_read_package_TDATA(axis_read_package.data),                // output wire [31 : 0] m_axis_read_package_TDATA
      .m_axis_tx_data_TVALID(axis_tx_data.valid),  // output wire m_axis_tx_data_TVALID
      .m_axis_tx_data_TREADY(axis_tx_data.ready),  // input wire m_axis_tx_data_TREADY
      .m_axis_tx_data_TDATA(axis_tx_data.data),  // output wire [63 : 0] m_axis_tx_data_TDATA
      .m_axis_tx_metadata_TVALID(axis_tx_metadata.valid),  // output wire m_axis_tx_metadata_TVALID
      .m_axis_tx_metadata_TREADY(axis_tx_metadata.ready),  // input wire m_axis_tx_metadata_TREADY
      .m_axis_tx_metadata_TDATA(axis_tx_metadata.data),                  // output wire [15 : 0] m_axis_tx_metadata_TDATA
      .s_axis_listen_port_status_TVALID(axis_listen_port_status.valid),  // input wire s_axis_listen_port_status_TVALID
      .s_axis_listen_port_status_TREADY(axis_listen_port_status.ready),  // output wire s_axis_listen_port_status_TREADY
      .s_axis_listen_port_status_TDATA(axis_listen_port_status.data),    // input wire [7 : 0] s_axis_listen_port_status_TDATA
      .s_axis_notifications_TVALID(axis_notifications.valid),            // input wire s_axis_notifications_TVALID
      .s_axis_notifications_TREADY(axis_notifications.ready),            // output wire s_axis_notifications_TREADY
      .s_axis_notifications_TDATA(axis_notifications.data),              // input wire [87 : 0] s_axis_notifications_TDATA
      .s_axis_open_status_TVALID(axis_open_status.valid),  // input wire s_axis_open_status_TVALID
      .s_axis_open_status_TREADY(axis_open_status.ready),  // output wire s_axis_open_status_TREADY
      .s_axis_open_status_TDATA(axis_open_status.data),                  // input wire [23 : 0] s_axis_open_status_TDATA
      .s_axis_rx_data_TVALID(axis_rx_data.valid),  // input wire s_axis_rx_data_TVALID
      .s_axis_rx_data_TREADY(axis_rx_data.ready),  // output wire s_axis_rx_data_TREADY
      .s_axis_rx_data_TDATA(axis_rx_data.data),  // input wire [63 : 0] s_axis_rx_data_TDATA
      .s_axis_rx_metadata_TVALID(axis_rx_metadata.valid),  // input wire s_axis_rx_metadata_TVALID
      .s_axis_rx_metadata_TREADY(axis_rx_metadata.ready),  // output wire s_axis_rx_metadata_TREADY
      .s_axis_rx_metadata_TDATA(axis_rx_metadata.data),                  // input wire [15 : 0] s_axis_rx_metadata_TDATA
      .s_axis_tx_status_TVALID(axis_tx_status.valid),  // input wire s_axis_tx_status_TVALID
      .s_axis_tx_status_TREADY(axis_tx_status.ready),  // output wire s_axis_tx_status_TREADY
      .s_axis_tx_status_TDATA(axis_tx_status.data),  // input wire [23 : 0] s_axis_tx_status_TDATA
      .ap_clk(aclk),  // input wire aclk
      .ap_rst_n(aresetn)  // input wire aresetn
  );
`endif

`ifdef IPERF_CLIENT
  wire       runExperiment;
  wire       dualMode;
  wire [7:0] noOfConnections;
  wire [7:0] pkgWordCount;

  vio_iperf vio_iperf_client_inst (
      .clk       (aclk),             // input wire clk
      .probe_out0(runExperiment),    // output wire [0 : 0] probe_out0
      .probe_out1(dualMode),         // output wire [0 : 0] probe_out1
      .probe_out2(noOfConnections),  // output wire [7 : 0] probe_out2
      .probe_out3(pkgWordCount)      // output wire [7 : 0] probe_out3
  );

  iperf_client_ip iperf_client (
      .m_axis_close_connection_TVALID(axis_close_connection_tvalid),      // output wire m_axis_close_connection_TVALID
      .m_axis_close_connection_TREADY(axis_close_connection_tready),      // input wire m_axis_close_connection_TREADY
      .m_axis_close_connection_TDATA(axis_close_connection_tdata),        // output wire [15 : 0] m_axis_close_connection_TDATA
      .m_axis_listen_port_TVALID(axis_listen_port_tvalid),  // output wire m_axis_listen_port_TVALID
      .m_axis_listen_port_TREADY(axis_listen_port_tready),  // input wire m_axis_listen_port_TREADY
      .m_axis_listen_port_TDATA(axis_listen_port_tdata),                  // output wire [15 : 0] m_axis_listen_port_TDATA
      .m_axis_open_connection_TVALID(axis_open_connection_tvalid),        // output wire m_axis_open_connection_TVALID
      .m_axis_open_connection_TREADY(axis_open_connection_tready),        // input wire m_axis_open_connection_TREADY
      .m_axis_open_connection_TDATA(axis_open_connection_tdata),          // output wire [47 : 0] m_axis_open_connection_TDATA
      .m_axis_read_package_TVALID(axis_read_package_tvalid),              // output wire m_axis_read_package_TVALID
      .m_axis_read_package_TREADY(axis_read_package_tready),              // input wire m_axis_read_package_TREADY
      .m_axis_read_package_TDATA(axis_read_package_tdata),                // output wire [31 : 0] m_axis_read_package_TDATA
      .m_axis_tx_data_TVALID(axis_tx_data_tvalid),  // output wire m_axis_tx_data_TVALID
      .m_axis_tx_data_TREADY(axis_tx_data_tready),  // input wire m_axis_tx_data_TREADY
      .m_axis_tx_data_TDATA(axis_tx_data_tdata),  // output wire [63 : 0] m_axis_tx_data_TDATA
      .m_axis_tx_data_TKEEP(axis_tx_data_tkeep),  // output wire [7 : 0] m_axis_tx_data_TKEEP
      .m_axis_tx_data_TLAST(axis_tx_data_tlast),  // output wire [0 : 0] m_axis_tx_data_TLAST
      .m_axis_tx_metadata_TVALID(axis_tx_metadata_tvalid),  // output wire m_axis_tx_metadata_TVALID
      .m_axis_tx_metadata_TREADY(axis_tx_metadata_tready),  // input wire m_axis_tx_metadata_TREADY
      .m_axis_tx_metadata_TDATA(axis_tx_metadata_tdata),                  // output wire [15 : 0] m_axis_tx_metadata_TDATA
      .s_axis_listen_port_status_TVALID(axis_listen_port_status_tvalid),  // input wire s_axis_listen_port_status_TVALID
      .s_axis_listen_port_status_TREADY(axis_listen_port_status_tready),  // output wire s_axis_listen_port_status_TREADY
      .s_axis_listen_port_status_TDATA(axis_listen_port_status_tdata),    // input wire [7 : 0] s_axis_listen_port_status_TDATA
      .s_axis_notifications_TVALID(axis_notifications_tvalid),            // input wire s_axis_notifications_TVALID
      .s_axis_notifications_TREADY(axis_notifications_tready),            // output wire s_axis_notifications_TREADY
      .s_axis_notifications_TDATA(axis_notifications_tdata),              // input wire [87 : 0] s_axis_notifications_TDATA
      .s_axis_open_status_TVALID(axis_open_status_tvalid),  // input wire s_axis_open_status_TVALID
      .s_axis_open_status_TREADY(axis_open_status_tready),  // output wire s_axis_open_status_TREADY
      .s_axis_open_status_TDATA(axis_open_status_tdata),                  // input wire [23 : 0] s_axis_open_status_TDATA
      .s_axis_rx_data_TVALID(axis_rx_data_tvalid),  // input wire s_axis_rx_data_TVALID
      .s_axis_rx_data_TREADY(axis_rx_data_tready),  // output wire s_axis_rx_data_TREADY
      .s_axis_rx_data_TDATA(axis_rx_data_tdata),  // input wire [63 : 0] s_axis_rx_data_TDATA
      .s_axis_rx_data_TKEEP(axis_rx_data_tkeep),  // input wire [7 : 0] s_axis_rx_data_TKEEP
      .s_axis_rx_data_TLAST(axis_rx_data_tlast),  // input wire [0 : 0] s_axis_rx_data_TLAST
      .s_axis_rx_metadata_TVALID(axis_rx_metadata_tvalid),  // input wire s_axis_rx_metadata_TVALID
      .s_axis_rx_metadata_TREADY(axis_rx_metadata_tready),  // output wire s_axis_rx_metadata_TREADY
      .s_axis_rx_metadata_TDATA(axis_rx_metadata_tdata),                  // input wire [15 : 0] s_axis_rx_metadata_TDATA
      .s_axis_tx_status_TVALID(axis_tx_status_tvalid),  // input wire s_axis_tx_status_TVALID
      .s_axis_tx_status_TREADY(axis_tx_status_tready),  // output wire s_axis_tx_status_TREADY
      .s_axis_tx_status_TDATA(axis_tx_status_tdata),  // input wire [23 : 0] s_axis_tx_status_TDATA

      //Client only
      .runExperiment(runExperiment | button_west),
      .dualModeEn_V   (dualMode),                     // input wire [0 : 0] dualModeEn_V
      .useConn_V      (noOfConnections),              // input wire [7 : 0] useConn_V
      .pkgWordCount_V (pkgWordCount),                 // input wire [7 : 0] pkgWordCount_V
      .regIpAddress0(32'h0B01D40A),                 // input wire [31 : 0] regIpAddress1_V
      .regIpAddress1(32'h0B01D40A),                 // input wire [31 : 0] regIpAddress1_V
      .regIpAddress2(32'h0B01D40A),                 // input wire [31 : 0] regIpAddress1_V
      .regIpAddress3(32'h0B01D40A),                 // input wire [31 : 0] regIpAddress1_V
      .aclk           (aclk),                         // input wire aclk
      .aresetn        (aresetn)                       // input wire aresetn
  );
`endif

  /*
 * UDP Application Module
 */
`ifdef UDP
  wire runUdpExperiment;

  vio_udp_iperf_client vio_udp_iperf_client_inst (
      .clk       (aclk),             // input wire clk
      .probe_out0(runUdpExperiment)  // output wire [0 : 0] probe_out0
  );

  reg runIperfUdp;
  reg [7:0] packetGap;
  always @(posedge aclk) begin
    if (~aresetn) begin
      runIperfUdp <= 0;
      packetGap   <= 0;
    end else begin
      runIperfUdp <= 0;
      if (button_north) begin
        packetGap   <= 0;
        runIperfUdp <= 1;
      end
      if (button_center) begin
        packetGap   <= 1;
        runIperfUdp <= 1;
      end
      if (button_south) begin
        packetGap   <= 9;
        runIperfUdp <= 1;
      end
    end
  end

  iperf_udp_client_ip iperf_udp_client_inst (
      .ap_clk(aclk),  // input wire aclk
      .ap_rst_n(aresetn),  // input wire aresetn
      .runExperiment(runUdpExperiment | runIperfUdp),  // input wire [0 : 0] runExperiment_V
      .packetGap(packetGap),
      //.regMyIpAddress(32'h02D4010B),                    // input wire [31 : 0] regMyIpAddress_V
      .targetIpAddress({
        target_ip_address, target_ip_address, target_ip_address, target_ip_address
      }),  // input wire [31 : 0] regTargetIpAddress_V

      .s_axis_rx_metadata_TVALID(axis_rx_udp_metadata.valid),
      .s_axis_rx_metadata_TREADY(axis_rx_udp_metadata.ready),
      .s_axis_rx_metadata_TDATA(axis_rx_udp_metadata.data),
      .s_axis_rx_data_TVALID(axis_rx_udp_data.valid),
      .s_axis_rx_data_TREADY(axis_rx_udp_data.ready),
      .s_axis_rx_data_TDATA(axis_rx_udp_data.data),

      .m_axis_tx_metadata_TVALID(axis_tx_udp_metadata.valid),
      .m_axis_tx_metadata_TREADY(axis_tx_udp_metadata.ready),
      .m_axis_tx_metadata_TDATA(axis_tx_udp_metadata.data),
      .m_axis_tx_data_TVALID(axis_tx_udp_data.valid),
      .m_axis_tx_data_TREADY(axis_tx_udp_data.ready),
      .m_axis_tx_data_TDATA(axis_tx_udp_data.data)
  );
`endif


  /*
 * DDR MEMORY
 */

  wire c0_init_calib_complete;
  wire c1_init_calib_complete;

  wire c0_ui_clk;
  wire ddr4_calib_complete;
  //wire init_calib_complete;
  //registers for crossing clock domains
  reg c0_init_calib_complete_r1, c0_init_calib_complete_r2;
  reg c1_init_calib_complete_r1, c1_init_calib_complete_r2;

  always @(posedge aclk)
    if (~aresetn) begin
      c0_init_calib_complete_r1 <= 1'b0;
      c0_init_calib_complete_r2 <= 1'b0;
      c1_init_calib_complete_r1 <= 1'b0;
      c1_init_calib_complete_r2 <= 1'b0;
    end else begin
      c0_init_calib_complete_r1 <= c0_init_calib_complete;
      c0_init_calib_complete_r2 <= c0_init_calib_complete_r1;
      c1_init_calib_complete_r1 <= c1_init_calib_complete;
      c1_init_calib_complete_r2 <= c1_init_calib_complete_r1;
    end

  assign ddr4_calib_complete = c0_init_calib_complete_r2 & c1_init_calib_complete_r2;


  mem_inf mem_inf_inst (
      .axi_clk(aclk),
      .aresetn(ddr4_calib_complete),
      .sys_rst(sys_reset),

      //ddr4 pins
      //SODIMM 0
      .c0_ddr4_adr     (c0_ddr4_adr),       // output wire [16 : 0] c0_ddr4_adr
      .c0_ddr4_ba      (c0_ddr4_ba),        // output wire [1 : 0] c0_ddr4_ba
      .c0_ddr4_cke     (c0_ddr4_cke),       // output wire [0 : 0] c0_ddr4_cke
      .c0_ddr4_cs_n    (c0_ddr4_cs_n),      // output wire [0 : 0] c0_ddr4_cs_n
      .c0_ddr4_dm_dbi_n(c0_ddr4_dm_dbi_n),  // inout wire [8 : 0] c0_ddr4_dm_dbi_n
      .c0_ddr4_dq      (c0_ddr4_dq),        // inout wire [71 : 0] c0_ddr4_dq
      .c0_ddr4_dqs_c   (c0_ddr4_dqs_c),     // inout wire [8 : 0] c0_ddr4_dqs_c
      .c0_ddr4_dqs_t   (c0_ddr4_dqs_t),     // inout wire [8 : 0] c0_ddr4_dqs_t
      .c0_ddr4_odt     (c0_ddr4_odt),       // output wire [0 : 0] c0_ddr4_odt
      .c0_ddr4_bg      (c0_ddr4_bg),        // output wire [0 : 0] c0_ddr4_bg
      .c0_ddr4_reset_n (c0_ddr4_reset_n),   // output wire c0_ddr4_reset_n
      .c0_ddr4_act_n   (c0_ddr4_act_n),     // output wire c0_ddr4_act_n
      .c0_ddr4_ck_c    (c0_ddr4_ck_c),      // output wire [0 : 0] c0_ddr4_ck_c
      .c0_ddr4_ck_t    (c0_ddr4_ck_t),      // output wire [0 : 0] c0_ddr4_ck_t

      .c0_ui_clk(c0_ui_clk),
      .c0_init_calib_complete(c0_init_calib_complete),

      // Differential system clocks
      .c0_sys_clk_p(c0_sys_clk_p),
      .c0_sys_clk_n(c0_sys_clk_n),
      .c1_sys_clk_p(c1_sys_clk_p),
      .c1_sys_clk_n(c1_sys_clk_n),

      //SODIMM 1
      // Inouts
      .c1_ddr4_adr     (c1_ddr4_adr),       // output wire [16 : 0] c1_ddr4_adr
      .c1_ddr4_ba      (c1_ddr4_ba),        // output wire [1 : 0] c1_ddr4_ba
      .c1_ddr4_cke     (c1_ddr4_cke),       // output wire [0 : 0] c1_ddr4_cke
      .c1_ddr4_cs_n    (c1_ddr4_cs_n),      // output wire [0 : 0] c1_ddr4_cs_n
      .c1_ddr4_dm_dbi_n(c1_ddr4_dm_dbi_n),  // inout wire [8 : 0] c1_ddr4_dm_dbi_n
      .c1_ddr4_dq      (c1_ddr4_dq),        // inout wire [71 : 0] c1_ddr4_dq
      .c1_ddr4_dqs_c   (c1_ddr4_dqs_c),     // inout wire [8 : 0] c1_ddr4_dqs_c
      .c1_ddr4_dqs_t   (c1_ddr4_dqs_t),     // inout wire [8 : 0] c1_ddr4_dqs_t
      .c1_ddr4_odt     (c1_ddr4_odt),       // output wire [0 : 0] c1_ddr4_odt
      .c1_ddr4_bg      (c1_ddr4_bg),        // output wire [0 : 0] c1_ddr4_bg
      .c1_ddr4_reset_n (c1_ddr4_reset_n),   // output wire c1_ddr4_reset_n
      .c1_ddr4_act_n   (c1_ddr4_act_n),     // output wire c1_ddr4_act_n
      .c1_ddr4_ck_c    (c1_ddr4_ck_c),      // output wire [0 : 0] c1_ddr4_ck_c
      .c1_ddr4_ck_t    (c1_ddr4_ck_t),      // output wire [0 : 0] c1_ddr4_ck_t

      .c1_ui_clk(),
      .c1_init_calib_complete(c1_init_calib_complete),

      //memory 0 read commands
      .s_axis_mem0_read_cmd_tvalid(axis_tcp_mem_read_cmd[0].valid),
      .s_axis_mem0_read_cmd_tready(axis_tcp_mem_read_cmd[0].ready),
      .s_axis_mem0_read_cmd_tdata({axis_tcp_mem_read_cmd[0].length, axis_tcp_mem_read_cmd[0].address}),
      //memory 0 read status
      .m_axis_mem0_read_sts_tvalid(axis_tcp_mem_read_status[0].valid),
      .m_axis_mem0_read_sts_tready(axis_tcp_mem_read_status[0].ready),
      .m_axis_mem0_read_sts_tdata(axis_tcp_mem_read_status[0].data),
      //memory 0 read stream
      .m_axis_mem0_read_tvalid(axis_tcp_mem_read_data[0].valid),
      .m_axis_mem0_read_tready(axis_tcp_mem_read_data[0].ready),
      .m_axis_mem0_read_tdata(axis_tcp_mem_read_data[0].data),
      .m_axis_mem0_read_tkeep(axis_tcp_mem_read_data[0].keep),
      .m_axis_mem0_read_tlast(axis_tcp_mem_read_data[0].last),

      //memory 0 write commands
      .s_axis_mem0_write_cmd_tvalid(axis_tcp_mem_write_cmd[0].valid),
      .s_axis_mem0_write_cmd_tready(axis_tcp_mem_write_cmd[0].ready),
      .s_axis_mem0_write_cmd_tdata({axis_tcp_mem_write_cmd[0].length, axis_tcp_mem_write_cmd[0].address}),
      //memory 0 write status
      .m_axis_mem0_write_sts_tvalid(axis_tcp_mem_write_status[0].valid),
      .m_axis_mem0_write_sts_tready(axis_tcp_mem_write_status[0].ready),
      .m_axis_mem0_write_sts_tdata(axis_tcp_mem_write_status[0].data),
      //memory 0 write stream
      .s_axis_mem0_write_tvalid(axis_tcp_mem_write_data[0].valid),
      .s_axis_mem0_write_tready(axis_tcp_mem_write_data[0].ready),
      .s_axis_mem0_write_tdata(axis_tcp_mem_write_data[0].data),
      .s_axis_mem0_write_tkeep(axis_tcp_mem_write_data[0].keep),
      .s_axis_mem0_write_tlast(axis_tcp_mem_write_data[0].last),

      //memory 1 read commands
      .s_axis_mem1_read_cmd_tvalid(axis_tcp_mem_read_cmd[1].valid),
      .s_axis_mem1_read_cmd_tready(axis_tcp_mem_read_cmd[1].ready),
      .s_axis_mem1_read_cmd_tdata({axis_tcp_mem_read_cmd[1].length, axis_tcp_mem_read_cmd[1].address}),
      //memory 1 read status
      .m_axis_mem1_read_sts_tvalid(axis_tcp_mem_read_status[1].valid),
      .m_axis_mem1_read_sts_tready(axis_tcp_mem_read_status[1].ready),
      .m_axis_mem1_read_sts_tdata(axis_tcp_mem_read_status[1].data),
      //memory 1 read stream
      .m_axis_mem1_read_tvalid(axis_tcp_mem_read_data[1].valid),
      .m_axis_mem1_read_tready(axis_tcp_mem_read_data[1].ready),
      .m_axis_mem1_read_tdata(axis_tcp_mem_read_data[1].data),
      .m_axis_mem1_read_tkeep(axis_tcp_mem_read_data[1].keep),
      .m_axis_mem1_read_tlast(axis_tcp_mem_read_data[1].last),

      //memory 1 write commands
      .s_axis_mem1_write_cmd_tvalid(axis_tcp_mem_write_cmd[1].valid),
      .s_axis_mem1_write_cmd_tready(axis_tcp_mem_write_cmd[1].ready),
      .s_axis_mem1_write_cmd_tdata({axis_tcp_mem_write_cmd[1].length, axis_tcp_mem_write_cmd[1].address}),
      //memory 1 write status
      .m_axis_mem1_write_sts_tvalid(axis_tcp_mem_write_status[1].valid),
      .m_axis_mem1_write_sts_tready(axis_tcp_mem_write_status[1].ready),
      .m_axis_mem1_write_sts_tdata(axis_tcp_mem_write_status[1].data),
      //memory 1 write stream
      .s_axis_mem1_write_tvalid(axis_tcp_mem_write_data[1].valid),
      .s_axis_mem1_write_tready(axis_tcp_mem_write_data[1].ready),
      .s_axis_mem1_write_tdata(axis_tcp_mem_write_data[1].data),
      .s_axis_mem1_write_tkeep(axis_tcp_mem_write_data[1].keep),
      .s_axis_mem1_write_tlast(axis_tcp_mem_write_data[1].last)

  );

endmodule

`default_nettype wire
