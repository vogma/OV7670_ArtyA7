# OV7670_ArtyA7
Project uses the OV7670 camera module on an Arty-A7 100T FPGA and streams the video to the VGA Port connected as PMOD
Vivado Version used: 2020.2

The image data is written from the camera interface to a dual port bram. The vga controller reads the pixel data and displays it. 
Due to the excessive use of the available bram (77% of the 100T) the 35T cannot be used for now. 
TODO: write pixel data to ddr ram 

To create project file:
make project
