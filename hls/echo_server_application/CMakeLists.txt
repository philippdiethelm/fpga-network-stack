# Author: David Sidler (david.sidler@inf.ethz.ch)

cmake_minimum_required(VERSION 3.0)

project(echo_server_application
        VERSION 1.2)

# Target options
set(FNS_PLATFORM_PART "xcu55c-fsvh2892-2L-e" CACHE STRING "FPGA platform part")

# Find Vitis
find_package(Vitis REQUIRED)

add_vitis_ip(${PROJECT_NAME}
                 FILES
                    "echo_server_application.cpp"
                    "echo_server_application.hpp"
                 TB_FILES
                    "test_echo_server_application.cpp"
                 HLS_FLAGS
                    "-DFNS_DATA_WIDTH=${FNS_DATA_WIDTH}"
                    "-DFNS_ROCE_STACK_MAX_QPS=${FNS_ROCE_STACK_MAX_QPS}"
                    "-DTCP_MSS=${FNS_TCP_STACK_MSS}"
                    "-DTCP_STACK_MAX_SESSIONS=${FNS_TCP_STACK_MAX_SESSIONS}"
                 PLATFORM_PART ${FNS_PLATFORM_PART}
                 VENDOR "ethz.systems.fpga"
                 DISPLAY_NAME "Echo Server Application for 10G TOE"
                 DESCRIPTION "Echos packets on connections coming in on port 7."
                 VERSION ${PROJECT_VERSION})
