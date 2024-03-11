#include <linux/ioctl.h>
#define IOC_MAGIC 'k'
#define IOCTL_ADD _IOWR(IOC_MAGIC,'+',int32_t*)
