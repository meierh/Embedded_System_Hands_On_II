# Makefile to build a misc driver for adder
# Helge
#

obj-m += misc_adder.o
KDIR := /lib/modules/6.2.10-1-aarch64-ARCH/build
PWD := $(shell pwd)

CC := $(CROSS_COMPILE)gcc

all:
	$(MAKE) -C $(KDIR) M=${shell pwd} modules
        
clean:
	-$(MAKE) -C $(KDIR) M=${shell pwd} clean || true
	-rm *.o *.ko *.mod.{c,o} modules.order Module.symvers || true
