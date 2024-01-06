#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#define MYSTERY_REGS_BASE_ADDR 0xA0000000
#define MYSTERY_REGS_END_ADDR  0xA000FFFF
#define MYSTERY_REGS_REG_SIZE 4

int main()
{
	printf("Mystery Regs Base: %x\n",MYSTERY_REGS_BASE_ADDR);
	printf("Mystery Regs End: %x\n",MYSTERY_REGS_END_ADDR);

	/* Open /dev/mem file */
	int fd;
	fd = open ("/dev/mem", O_RDWR);
	if (fd < 0)
       	{
		perror("Failed to open main memory (/dev/mem)");
		return EXIT_FAILURE;
	}
	printf("Opened memory\n");
	
	unsigned long long page_size=sysconf(_SC_PAGESIZE);
	printf("Pagesize:%d\n",page_size);

	/* Map MysteryRegs registers into memory*/
	int mysteryRegsMemSize = MYSTERY_REGS_END_ADDR-MYSTERY_REGS_BASE_ADDR;
	printf("Map size: %d\n",mysteryRegsMemSize);
	char* addressBase = mmap
	(
		NULL,
		mysteryRegsMemSize,
		PROT_READ|PROT_WRITE,
		MAP_SHARED,
		fd,
		MYSTERY_REGS_BASE_ADDR
	);	
	if(addressBase == MAP_FAILED)
	{
		printf("mmap failed. see errno for reason.\n");
		close(fd);
		return EXIT_FAILURE;
	}    
	char* address0 = addressBase;
	char* address4 = addressBase +  4;
	char* address8 = addressBase +  8;
	char* address12= addressBase + 12;
	char* address16= addressBase + 16;
	printf("Mapped main memory to pointer: %4x\n",addressBase);

	/* Transform to 32-bit integer pointers */
	int32_t* addrInt0 = (int32_t*) address0;
	int32_t* addrInt4 = (int32_t*) address4;
	int32_t* addrInt8 = (int32_t*) address8;
	int32_t* addrInt12 = (int32_t*) address12;
	int32_t* addrInt16 = (int32_t*) address16;
	printf("Register Adresses[r0:%4x , r4:%4x , r8:%4x , r12:%4x , r16:%4x]\n",addrInt0,addrInt4,addrInt8,addrInt12,addrInt16);

	// Find Register 0 functionality
	printf("-------Find Register 0 (r0): %4x functionality-------\n",addrInt0);
	printf("\tInitial Read [r0:%d]\n",*addrInt0);
	*addrInt0 = -4;
	printf("\tWrite -4 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = -3;
	printf("\tWrite -3 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = -3;
	printf("\tWrite -3 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = -2;
	printf("\tWrite -2 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = -2;
	printf("\tWrite -2 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = -1;
	printf("\tWrite -1 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 0;
	printf("\tWrite 0 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 1;
	printf("\tWrite 1 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 2;	
	printf("\tWrite 2 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 2;	
	printf("\tWrite 2 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 3;	
	printf("\tWrite 3 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 3;	
	printf("\tWrite 3 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 4;	
	printf("\tWrite 4 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 8;	
	printf("\tWrite 8 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 16;	
	printf("\tWrite 16 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 32;	
	printf("\tWrite 32 to r0 and read [r0:%d]\n",*addrInt0);
	*addrInt0 = 64;	
	printf("\tWrite 64 to r0 and read [r0:%d]\n",*addrInt0);
	printf("----------------------------------------------------------\n");    

	// Find Register 4 functionality
	printf("-------Find Register 4 (r4): %4x functionality-------\n",addrInt4);
	printf("\tInitial Read [r4:%d]\n",*addrInt4);
	*addrInt4 = -4;
	printf("\tWrite -4 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = -3;
	printf("\tWrite -3 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = -3;
	printf("\tWrite -3 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = -2;
	printf("\tWrite -2 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = -2;
	printf("\tWrite -2 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = -1;
	printf("\tWrite -1 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 0;
	printf("\tWrite 0 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 1;
	printf("\tWrite 1 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 2;	
	printf("\tWrite 2 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 2;	
	printf("\tWrite 2 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 3;	
	printf("\tWrite 3 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 3;	
	printf("\tWrite 3 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 4;	
	printf("\tWrite 4 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 8;	
	printf("\tWrite 8 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 16;	
	printf("\tWrite 16 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 32;	
	printf("\tWrite 32 to r4 and read [r4:%d]\n",*addrInt4);
	*addrInt4 = 64;	
	printf("\tWrite 64 to r4 and read [r4:%d]\n",*addrInt4);
	printf("----------------------------------------------------------\n");    

	// Find Register 8 functionality
	printf("-------Find Register 8 (r8): %4x functionality-------\n",addrInt8);
	printf("\tInitial Read [r8:%d]\n",*addrInt8);
	*addrInt8 = -4;
	printf("\tWrite -4 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = -3;
	printf("\tWrite -3 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = -3;
	printf("\tWrite -3 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = -2;
	printf("\tWrite -2 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = -2;
	printf("\tWrite -2 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = -1;
	printf("\tWrite -1 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 0;
	printf("\tWrite 0 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 1;
	printf("\tWrite 1 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 2;	
	printf("\tWrite 2 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 2;	
	printf("\tWrite 2 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 3;
	printf("\tWrite 3 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 3;	
	printf("\tWrite 3 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 4;	
	printf("\tWrite 4 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 8;	
	printf("\tWrite 8 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 16;	
	printf("\tWrite 16 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 32;	
	printf("\tWrite 32 to r8 and read [r8:%d]\n",*addrInt8);
	*addrInt8 = 64;	
	printf("\tWrite 64 to r8 and read [r8:%d]\n",*addrInt8);
	printf("----------------------------------------------------------\n");    

	// Find Register 12 functionality
	printf("-------Find Register 12 (r12): %4x functionality-------\n",addrInt12);
	int32_t value = 13;
	printf("\tInitial Read [r12:%d]\n",*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = 10;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = 23;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);	
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = 2;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12); 
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = 0;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12); 
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = -1;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12); 
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = -3;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12); 
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	value = 5;
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12); 
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	*addrInt12 = value;
	printf("\tWrite %d to r12 and read [r12:%d]\n",value,*addrInt12);
	printf("----------------------------------------------------------\n");   

	// Find Register 16 functionality
	printf("-------Find Register 16 (r16): %4x functionality-------\n",addrInt16);
	printf("\tInitial Read [r16:%d]\n",*addrInt16);
	for(int i=1;i<47;i++)
		printf("\tRead [r16:%d]\n",*addrInt16);
	printf("----------------------------------------------------------\n");

	munmap(addressBase,mysteryRegsMemSize);
	close(fd);
	printf("End of MysteryRegs Tester!\n");
	return EXIT_SUCCESS;
}
