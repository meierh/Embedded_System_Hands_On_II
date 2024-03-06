#include <linux/ioctl.h>
#define IOC_MAGIC 'k'
#define IOCTL_DCTNUMBLOCKS _IOW(IOC_MAGIC,'n',uint32_t*)
#define IOCTL_DCTDMAMALLOC _IO(IOC_MAGIC,'m')
#define IOCTL_DCTINPUTDATA _IOW(IOC_MAGIC,'i',uint8_t*)
#define IOCTL_DCTEXECCMD _IO(IOC_MAGIC,'e')
#define IOCTL_WAIT _IO(IOC_MAGIC,'w')
#define IOCTL_DCTOUTPUTDATA _IOR(IOC_MAGIC,'o',uint8_t*)
#define IOCTL_DCTDMAFREE _IO(IOC_MAGIC,'f')
#define IOCTL_DCTSTATUS _IOR(IOC_MAGIC,'s',uint32_t*)
