#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include "ioctl_adder.h"

int main()
{
	int fd = open("/dev/misc_adder", O_RDWR);
	if(fd<0)
	{
		printf("Cannot open adder device\n");
		return -1;
	}
	
	int32_t data[3];
	int32_t* a = data;
	int32_t* b = data+1;
	int32_t* c = data+2;

	//Test Adder functionality
	printf("-----Test Adder functionality-----\n");
	*a = 13;
	*b = 87;
	ioctl(fd,IOCTL_ADD,data);
	printf("	%3d + %3d = %3d\n",*a,*b,*c);

	ioctl(fd,IOCTL_ADD,data);
	printf("	%3d + %3d = %3d\n",*a,*b,*c);

	*a = 33;
	ioctl(fd,IOCTL_ADD,data);
	printf("	%3d + %3d = %3d\n",*a,*b,*c);

	*b = 57;
	ioctl(fd,IOCTL_ADD,data);
	printf("	%3d + %3d = %3d\n",*a,*b,*c);

	*b = 22;
	ioctl(fd,IOCTL_ADD,data);
	printf("	%3d + %3d = %3d\n",*a,*b,*c);

	*b = -43;
	ioctl(fd,IOCTL_ADD,data);
	printf("	%3d + %3d = %3d\n",*a,*b,*c);

	printf("----------------------------------\n");
	close(fd);
	return 0;
}
