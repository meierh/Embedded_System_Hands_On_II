#!/bin/bash

bitstream_name=$1
echo "Loading bitstream: ${bitstream_name}"

#Test for correct arguments
splitted_bitstream_name=(${bitstream_name//./ })
if [[ ${splitted_bitstream_name[1]} != *"bit"* ]] || [[ ${splitted_bitstream_name[2]} != *"bin"* ]]; then
    echo "ERROR: Invalid file parameter"
    exit 1
fi

#Test for fpga manager
{
    ls -l /sys/class/fpga_manager &> /dev/null
} || {
    echo "ERROR: FPGA Manager does not exist"
    exit 1
}

#Set flags for full bistream
echo 0 > /sys/class/fpga_manager/fpga0/flags

#Loading Bitstream into PL
mkdir -p /lib/firmware
cp ${bitstream_name} /lib/firmware/
echo ${bitstream_name} > /sys/class/fpga_manager/fpga0/firmware
