obj-m := snd-soc-max98357a.o
snd-soc-max98357a-y := max98357a.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(CURDIR) modules
