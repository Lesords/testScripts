# Vendor Storage Tools Makefile

CC = $(CROSS_COMPILE)gcc
CFLAGS = -Wall -O2
TARGETS = vendor_storage_official vendor_storage

all: $(TARGETS)

vendor_storage_official: vendor_storage_official.c
	$(CC) $(CFLAGS) -o $@ $<

vendor_storage: vendor_storage.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS)

install:
	install -m 755 vendor_storage_official /usr/local/bin/
	install -m 755 vendor_storage /usr/local/bin/

help:
	@echo "vendor-storage tools"
	@echo ""
	@echo "Usage:"
	@echo "  make                                     Build on device (needs gcc)"
	@echo "  make CROSS_COMPILE=aarch64-linux-gnu-    Cross-compile on host"
	@echo "  make clean                               Remove binaries"
	@echo "  make install                             Install to /usr/local/bin/"
	@echo "  make help                                Show this help"
	@echo ""
	@echo "Targets:"
	@echo "  vendor_storage_official    Official buildroot tool"
	@echo "                             -r ID / -w ID,DATA / -R (read all)"
	@echo "  vendor_storage             Simplified custom tool"
	@echo "                             -r ID -t hex / -w ID -t hex -i DATA"
	@echo ""
	@echo "Deploy to device:"
	@echo "  make CROSS_COMPILE=aarch64-linux-gnu- && \\"
	@echo "  scp vendor_storage* root@<ip>:/usr/local/bin/"

.PHONY: all clean install help
