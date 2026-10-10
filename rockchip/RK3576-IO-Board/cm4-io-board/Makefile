# Standalone DT overlay build for the CM4-style IO board (RK3576).
# No kernel tree or cross toolchain needed — only system dtc + cpp.
# Output is byte-identical to the kernel tree build.

DTS_DIR  := dts
INC_DIR  := include
OUT_DIR  := output

# Deploy target (make install DEVICE=<ip>)
DEVICE   ?= 10.0.0.128

DTS_SRCS := $(wildcard $(DTS_DIR)/*.dts)
HDRS     := $(wildcard $(INC_DIR)/dt-bindings/*/*.h)
DTBOS    := $(patsubst $(DTS_DIR)/%.dts,$(OUT_DIR)/%.dtbo,$(DTS_SRCS))

CPPFLAGS := -nostdinc -I $(INC_DIR) -undef -D__DTS__ -x assembler-with-cpp
DTCFLAGS := -@ -Hepapr -q -I dts -O dtb

.PHONY: all install clean

all: $(DTBOS)

$(OUT_DIR)/%.dtbo: $(DTS_DIR)/%.dts $(HDRS) | $(OUT_DIR)
	$(CPP) $(CPPFLAGS) $< | dtc $(DTCFLAGS) -o $@ -

$(OUT_DIR):
	mkdir -p $@

install: all
	scp $(DTBOS) root@$(DEVICE):/boot/dtb/rockchip/overlay/

clean:
	rm -f $(OUT_DIR)/*.dtbo
