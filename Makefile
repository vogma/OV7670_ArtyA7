QUIET = -nojournal -nolog -notrace
BATCH_MODE = -mode batch
TCLARGS = -tclargs $(bitfile)

project:
	vivado $(BATCH_MODE) -source OV7670_ArtyA7.tcl $(QUIET)
