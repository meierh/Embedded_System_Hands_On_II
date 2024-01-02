#include <linux/ioctl.h>
#define IOC_MAGIC_k ioc_adder_num
#define IOCTL_ADD _IOWR(ioc_adder_num,'abc',int32_t*);
