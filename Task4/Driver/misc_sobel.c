#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
/*#include <asm/io.h>*/
#include <linux/dma-mapping.h>
#include "ioctl_sobel.h"

#define AXI_PAGE_SIZE 4096
#define ADDER_REGS_BASE_ADDR 0xA0000000
#define ADDER_REGS_END_ADDR 0xA0000FFF
#define ADDER_REGS_SIZE 4

static uint32_t numberOfChunksX=0;
static uint32_t resolutionY=0;

static uint32_t inImageDataByteSize;
static uint32_t inImageMemByteSize;
static dma_addr_t inImageDataDMAHandle;
static dma_addr_t inImageMemDMAHandle;
void* inImageDataDMAcpu;
void* inImageMemDMAcpu;

static uint32_t outImageDataByteSize;
static uint32_t outImageMemByteSize;
static dma_addr_t outImageDataDMAHandle;
static dma_addr_t outImageMemDMAHandle;
void* outImageDataDMAcpu;
void* outImageMemDMAcpu;

static char* sobelBase = NULL;
static uint32_t* sobelStatus;		//0
static uint32_t* sobelInputAXIAddr;	//4
static uint32_t* sobelOutputAXIAddr;	//8
static uint32_t* sobelChunkXCount;	//12
static uint32_t* sobelResolutionY;	//16
static uint32_t* sobelKernel;		//20
static uint32_t* sobelExec;		//24

static long sobel_ioctl(struct file *f, unsigned int cmd, unsigned long arg);

static const struct file_operations sobel_fops = {
    .owner			= THIS_MODULE,
    .unlocked_ioctl	= sobel_ioctl
};

struct miscdevice sobel_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "misc_sobel",
    .fops = &sobel_fops,
};

static long sobel_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
    switch(cmd)
    {
        /* Writes number of chunks in x direction to hardware and to memory allocation in driver
         */
        case IOCTL_SOBELCHUNKSX:
        {
            int writeError = copy_from_user(sobelChunkXCount,(uint32_t*)arg,4);
            if(writeError)
                pr_err("Sobel Driver Error: Writing number of chunks in x direction failed\n");
    
            writeError = copy_from_user(&numberOfChunksX,(uint32_t*)arg,4);
            if(writeError)
                pr_err("Sobel Driver Error: Writing number of chunks in x direction failed\n");

            break;
        }
        /* Writes number of chunks in x direction to hardware and to memory allocation in driver
         */
        case IOCTL_SOBELRESY:
        {
            int writeError = copy_from_user(sobelResolutionY,(uint32_t*)arg,4);
            if(writeError)
                pr_err("Sobel Driver Error: Writing number of resolution in y direction failed\n");
    
            writeError = copy_from_user(&resolutionY,(uint32_t*)arg,4);
            if(writeError)
                pr_err("Sobel Driver Error: Writing number of resolution in y direction failed\n");

            break;
        }
	/* Write Kernel type to hardware. Must be 0->Sobel3, 1->Sobel5, 2->Sobel7 
	 */
	case IOCTL_SOBELKERNEL:
	{
	    int writeError = copy_from_user(sobelKernel,(uint32_t*)arg,4);
	    if(writeError)
		pr_err("Sobel Driver Error: Writing kernel type failed\n");
	    break;
	}
        /* Allocate dma memory allocation. Uses numbers set by IOCTL_SOBELCHUNKSX and IOCTL_SOBELRESY
         */
        case IOCTL_SOBELDMAMALLOC:
        {
            inImageDataByteSize = numberOfChunksX*resolutionY*16;
            outImageDataByteSize = numberOfChunksX*(resolutionY-6)*16;

            inImageMemByteSize = inImageDataByteSize+AXI_PAGE_SIZE;
            outImageMemByteSize = outImageDataByteSize+AXI_PAGE_SIZE;
            
            inImageMemDMAcpu = dma_alloc_coherent(sobel_device.this_device,inImageMemByteSize,&inImageMemDMAHandle,GFP_KERNEL);
            if(inImageMemDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of input image dma failed\n");
            uint32_t inOffsetToNextPage = ((uint32_t)inImageMemDMAHandle)%AXI_PAGE_SIZE;
            inImageDataDMAcpu = inImageMemDMAcpu+inOffsetToNextPage;
            inImageDataDMAHandle = inImageMemDMAHandle+inOffsetToNextPage;
            *sobelInputAXIAddr = (uint32_t)inImageDataDMAHandle;

            outImageMemDMAcpu = dma_alloc_coherent(sobel_device.this_device,outImageMemByteSize,&outImageMemDMAHandle,GFP_KERNEL);
            if(outImageMemDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of output image dma failed\n");
            uint32_t outOffsetToNextPage = ((uint32_t)outImageMemDMAHandle)%AXI_PAGE_SIZE;
            outImageDataDMAcpu = outImageMemDMAcpu+outOffsetToNextPage;
            outImageDataDMAHandle = outImageMemDMAHandle+outOffsetToNextPage;
            *sobelOutputAXIAddr = (uint32_t) outImageDataDMAHandle;

            break;
        }
        /* Copy input image data to driver dma memory. Uses numbers set by IOCTL_SOBELCHUNKSX and IOCTL_SOBELRESY
         * Requires previous allocation of memory by IOCTL_SOBELDMAMALLOC
        */
        case IOCTL_SOBELINPUTDATA:
      	{
            int writeError = copy_from_user((uint8_t*)inImageDataDMAcpu,(uint8_t*)arg,inImageDataByteSize);   
            if(writeError)
                pr_err("DCT Driver Error: Copy to DMA input memory failed\n");
            
            break;
        }
        /* Starts hardware and waits for completion
        */
        case IOCTL_SOBELEXECCMD:
	{		
            *sobelExec = 1;
            pr_info("Executed Sobel on %d chunks\n",numberOfChunksX*resolutionY);
            while(*sobelStatus==1)
            {
                pr_info("Running Sobel\n");
            }
            pr_info("Completed Sobel\n");
            break;
        }
        /* Wait for hardware to be ready
        */
        case IOCTL_SOBELWAIT:
        {
            while(*sobelStatus==1)
            {
                pr_info("Running Sobel\n");
            }
            pr_info("Completed Sobel\n");
            break;
        }
        /* Copy output image data from driver dma memory. Uses numbers set by IOCTL_SOBELCHUNKSX and IOCTL_SOBELRESY
         * Requires previous allocation of memory by IOCTL_SOBELDMAMALLOC
        */
        case IOCTL_SOBELOUTPUTDATA:
        {
            int readError = copy_to_user((uint8_t*)arg,(uint8_t*)outImageDataDMAcpu,outImageDataByteSize);   
            if(readError)
                pr_err("Sobel Driver Error: Copy from DMA output memory failed\n");

            break;
        }
        /* Frees allocated dma memory. Requires previous allocation of memory by IOCTL_DCTDMAMALLOC
         */
        case IOCTL_SOBELDMAFREE:
        {
            dma_free_coherent(sobel_device.this_device,inImageMemByteSize,inImageMemDMAcpu,inImageMemDMAHandle);
            dma_free_coherent(sobel_device.this_device,outImageMemByteSize,outImageMemDMAcpu,outImageMemDMAHandle);
            break;
        }
        /* Read sobel status
        */
        case IOCTL_SOBELSTATUS:
	{
            pr_info("Dev status:%d\n",*sobelStatus);
            int readError = copy_to_user((uint32_t*)arg,sobelStatus,4);
            if(readError)
                pr_err("Sobel Driver Error: Reading sobel status failed\n");
            break;
        }
        default:
            return -ENOTTY;
    }
    return 0;
}

static void __exit misc_exit(void);

static int __init misc_init(void)
{
    int error;
    error = misc_register(&sobel_device);
    if (error)
    {
        pr_err("Error: Register of sobel driver failed\n");
        return error;
    }
   
    error = dma_set_coherent_mask(sobel_device.this_device,DMA_BIT_MASK(31));
    if(error)
    {
        pr_err("Error: Device can not perform DMA with the given mask\n");
        return error;
    }
    
    sobelBase = ioremap(ADDER_REGS_BASE_ADDR,7*ADDER_REGS_SIZE);
    if(sobelBase==NULL)
    {
        pr_err("Error: Mapping of io memory failed\n");
        return error;
    }
    sobelStatus = (uint32_t*) sobelBase;
    sobelInputAXIAddr = sobelStatus + 1;
    sobelOutputAXIAddr = sobelInputAXIAddr + 1;
    sobelChunkXCount = sobelOutputAXIAddr + 1;
    sobelResolutionY = sobelChunkXCount + 1;
    sobelKernel = sobelResolutionY + 1;
    sobelExec = sobelKernel + 1;
    pr_info("Sobel Device loaded\n");
    return 0;
}

static void __exit misc_exit(void)
{
    if(sobelBase!=NULL)
    {
        iounmap(sobelBase);
    }
    misc_deregister(&sobel_device);
    pr_info("Sobel device unloaded\n");
}

module_init(misc_init)
module_exit(misc_exit)

MODULE_DESCRIPTION("Misc Driver for Sobel");
MODULE_AUTHOR("Helge Meier");
MODULE_LICENSE("GPL");
