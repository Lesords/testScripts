/*
 * vendor_storage — Rockchip eMMC Vendor Storage Tool
 * Based on: buildroot/package/rockchip/vendor_storage/vendor_storage.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <stdint.h>

#define VENDOR_REQ_TAG 0x56524551

#define VENDOR_SN_ID        1
#define VENDOR_WIFI_MAC_ID  2
#define VENDOR_LAN_MAC_ID   3
#define VENDOR_BT_MAC_ID    4
#define VENDOR_IMEI_ID      5

#define VENDOR_READ_IO  _IOW(0x76, 0x01, unsigned int)
#define VENDOR_WRITE_IO _IOW(0x76, 0x02, unsigned int)

struct rk_vendor_req {
	uint32_t tag;
	uint16_t id;
	uint16_t len;
	uint8_t data[1024];
};

static const char *id_names[] = {
	[0] = "VENDOR_RSV_ID",
	[VENDOR_SN_ID] = "VENDOR_SN_ID",
	[VENDOR_WIFI_MAC_ID] = "VENDOR_WIFI_MAC_ID",
	[VENDOR_LAN_MAC_ID] = "VENDOR_LAN_MAC_ID",
	[VENDOR_BT_MAC_ID] = "VENDOR_BT_MAC_ID",
	[VENDOR_IMEI_ID] = "VENDOR_IMEI_ID",
};

static int id_from_name(const char *name)
{
	for (int i = 0; i < 6; i++)
		if (id_names[i] && strcmp(name, id_names[i]) == 0)
			return i;
	return atoi(name);
}

static void print_hex(uint8_t *buf, int len)
{
	for (int i = 0; i < len; i++)
		printf("%02x%s", buf[i], (i == len - 1) ? "" : ":");
	printf("\n");
}

static void usage(void)
{
	fprintf(stderr,
		"Usage: vendor_storage -w <ID> -t <type> -i <data>\n"
		"       vendor_storage -r <ID> -t <type>\n"
		"\n"
		"Options:\n"
		"  -w <ID>   Write (ID name or number)\n"
		"  -r <ID>   Read  (ID name or number)\n"
		"  -t <type> Data type: string | hex\n"
		"  -i <data> Data to write (for MAC: hex like AABBCCDDEEFF)\n"
		"\n"
		"IDs:\n");
	for (int i = 1; i < 6; i++)
		fprintf(stderr, "  %d  %s\n", i, id_names[i]);
}

int main(int argc, char **argv)
{
	int fd, opt, id = -1, is_write = 0, is_hex = 0;
	char data_str[2048] = {0};
	struct rk_vendor_req req;

	while ((opt = getopt(argc, argv, "w:r:t:i:h")) != -1) {
		switch (opt) {
		case 'w': is_write = 1; id = id_from_name(optarg); break;
		case 'r': is_write = 0; id = id_from_name(optarg); break;
		case 't': is_hex = (strcmp(optarg, "hex") == 0); break;
		case 'i': strncpy(data_str, optarg, sizeof(data_str) - 1); break;
		case 'h': usage(); return 0;
		default: usage(); return 1;
		}
	}

	if (id < 0 || (is_write && !data_str[0])) {
		usage();
		return 1;
	}

	fd = open("/dev/vendor_storage", O_RDWR);
	if (fd < 0) {
		perror("open /dev/vendor_storage");
		return 1;
	}

	memset(&req, 0, sizeof(req));
	req.tag = VENDOR_REQ_TAG;
	req.id = id;

	if (is_write) {
		if (is_hex) {
			int len = strlen(data_str) / 2;
			for (int i = 0; i < len && i < 1024; i++)
				sscanf(data_str + i * 2, "%2hhx", &req.data[i]);
			req.len = len;
		} else {
			strcpy((char *)req.data, data_str);
			req.len = strlen(data_str);
		}

		printf("Writing %s (id=%d, %d bytes): ", id_names[id], id, req.len);
		print_hex(req.data, req.len > 6 ? 6 : req.len);

		if (ioctl(fd, VENDOR_WRITE_IO, &req) < 0) {
			fprintf(stderr, "WRITE failed: %s (errno=%d)\n", strerror(errno), errno);
			close(fd);
			return 1;
		}
		printf("Write OK\n");
	} else {
		req.len = sizeof(req.data);
		if (ioctl(fd, VENDOR_READ_IO, &req) < 0) {
			fprintf(stderr, "READ failed: %s (errno=%d)\n", strerror(errno), errno);
			close(fd);
			return 1;
		}
		printf("%s (id=%d, %d bytes): ", id_names[id], id, req.len);
		if (is_hex)
			print_hex(req.data, req.len);
		else
			printf("%.*s\n", req.len, req.data);
	}

	close(fd);
	return 0;
}
