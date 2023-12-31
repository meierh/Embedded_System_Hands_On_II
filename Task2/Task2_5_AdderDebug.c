#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#define MYSTERY_REGS_BASE_ADDR 0xA0000000
#define MYSTERY_REGS_END_ADDR  0xA0000FFF
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
	char* writeAByte = addressBase;
	char* writeBByte = addressBase +  4;
	char* readCByte = addressBase +  8;
	printf("Mapped main memory to pointer: %4x\n",addressBase);

	/* Transform to 32-bit integer pointers */
	int32_t* writeA = (int32_t*) writeAByte;
	int32_t* writeB = (int32_t*) writeBByte;
	int32_t* readC = (int32_t*) readCByte;
	printf("Register Adresses[wA:%4x , wB:%4x , rC:%4x]\n",writeA,writeB,readC);

	// Test Adder functionality
	printf("-------Test Adder functionality-------\n");
	*writeA = 13;
	printf("\tWrite 13 to a\n");
	
	*writeB = 87;
	printf("\tWrite 87 to b\n");
	
	printf("Read %d from c\n",*readC);
	
	printf("Read %d from c\n",*readC);
	
	*writeA = 33;
	printf("\tWrite 33 to a\n");
	
	printf("Read %d from c\n",*readC);
	
	*writeB = 57;
	printf("\tWrite 57 to b\n");
	
	printf("Read %d from c\n",*readC);
	
	*writeB = 27;
	printf("\tWrite 27 to b\n");
	
	*writeB = -43;
	printf("\tWrite -43 to b\n");
	
	printf("Read %d from c\n",*readC);
	
	printf("----------------------------------------------------------\n");   

	munmap(addressBase,mysteryRegsMemSize);
	close(fd);
	printf("End of MysteryRegs Tester!\n");
	return EXIT_SUCCESS;
}
