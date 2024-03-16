#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
/*#include <asm/io.h>*/
#include <linux/dma-mapping.h>
#include "ioctl_dct.h"

#define AXI_PAGE_SIZE 4096
#define ADDER_REGS_BASE_ADDR 0xA0000000
#define ADDER_REGS_END_ADDR 0xA0000FFF
#define ADDER_REGS_SIZE 4

static uint32_t numberOfBlocks=0;

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

static char* dctBase = NULL;
static uint32_t* dctStatus;		//0
static uint32_t* dctInputAXIAddr;	//4
static uint32_t* dctOutputAXIAddr;	//8
static uint32_t* dctNumBlocks;		//12
static uint32_t* dctExec;		//16

static long dct_ioctl(struct file *f, unsigned int cmd, unsigned long arg);

static const struct file_operations dct_fops = {
    .owner			= THIS_MODULE,
    .unlocked_ioctl	= dct_ioctl
};

struct miscdevice dct_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "misc_dct",
    .fops = &dct_fops,
};

static long dct_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
    switch(cmd)
    {
        case IOCTL_DCTNUMBLOCKS:
        {
            int writeError = copy_from_user(dctNumBlocks,(uint32_t*)arg,4);
            if(writeError)
                pr_err("DCT Driver Error: Writing number of blocks failed\n");
    
    	    writeError = copy_from_user(&numberOfBlocks,(uint32_t*)arg,4);
	    if(writeError)
		 pr_err("DCT Driver Error: Writing number of blocks failed\n");
	    // pr_info("Write %d blocks\n",numberOfBlocks);

            inImageDataByteSize = numberOfBlocks*64;
            outImageDataByteSize = numberOfBlocks*64*2;

	    inImageMemByteSize = inImageDataByteSize+AXI_PAGE_SIZE;
	    outImageMemByteSize = outImageDataByteSize+AXI_PAGE_SIZE;

	    /*
	    pr_info("inImageDataByteSize: %d\n",inImageDataByteSize);
	    pr_info("inImageMemByteSize: %d\n",inImageMemByteSize);
	    pr_info("outImageDataByteSize: %d\n",outImageDataByteSize);
	    pr_info("outImageMemByteSize: %d\n",outImageMemByteSize);
            */

	    break;
        }
        case IOCTL_DCTDMAMALLOC:
	{
            inImageMemDMAcpu = dma_alloc_coherent(dct_device.this_device,inImageMemByteSize,&inImageMemDMAHandle,GFP_KERNEL);
            if(inImageMemDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of input image dma failed\n");
            uint32_t inOffsetToNextPage = ((uint32_t)inImageMemDMAHandle)%AXI_PAGE_SIZE;
	    inImageDataDMAcpu = inImageMemDMAcpu+inOffsetToNextPage;
	    inImageDataDMAHandle = inImageMemDMAHandle+inOffsetToNextPage;
	    *dctInputAXIAddr = (uint32_t)inImageDataDMAHandle;

	    /*
	    pr_info("inOffsetToNextPage: %d\n",inOffsetToNextPage);
	    pr_info("inImageMemDMAHandle: %d\n",(uint64_t)inImageMemDMAHandle);
	    pr_info("inImageDataDMAHandle: %d\n",(uint64_t)inImageDataDMAHandle);
	    pr_info("inImageMemDMAcpu: %d\n",(uint64_t)inImageMemDMAcpu);
	    pr_info("inImageDataDMAcpu: %d\n",(uint64_t)inImageDataDMAcpu);
	    */

	    outImageMemDMAcpu = dma_alloc_coherent(dct_device.this_device,outImageMemByteSize,&outImageMemDMAHandle,GFP_KERNEL);
            if(outImageMemDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of output image dma failed\n");
	    uint32_t outOffsetToNextPage = ((uint32_t)outImageMemDMAHandle)%AXI_PAGE_SIZE;
	    outImageDataDMAcpu = outImageMemDMAcpu+outOffsetToNextPage;
	    outImageDataDMAHandle = outImageMemDMAHandle+outOffsetToNextPage;
            *dctOutputAXIAddr = (uint32_t) outImageDataDMAHandle;

	    /*
	    pr_info("outOffsetToNextPage: %d\n",outOffsetToNextPage);
    	    pr_info("outImageMemDMAHandle: %d\n",(uint64_t)outImageMemDMAHandle);
	    pr_info("outImageDataDMAHandle: %d\n",(uint64_t)outImageDataDMAHandle);
	    pr_info("outImageMemDMAcpu: %d\n",(uint64_t)outImageMemDMAcpu);
	    pr_info("outImageDataDMAcpu: %d\n",(uint64_t)outImageDataDMAcpu);
	    */
            break;
        }
        case IOCTL_DCTINPUTDATA:
        {
            int writeError = copy_from_user((uint8_t*)inImageDataDMAcpu,(uint8_t*)arg,inImageDataByteSize);   
            if(writeError)
                pr_err("DCT Driver Error: Copy to DMA input memory failed\n");
	    /*
            pr_info("Write %d bytes to in image\n",inImageDataByteSize);
	    pr_info("Data %d\n",*((uint8_t*)inImageDataDMAcpu));
	    */
	    break;
        }
        case IOCTL_DCTEXECCMD:
        {
	    *dctExec = 1;
	    pr_info("Executed DCT on %d blocks\n",numberOfBlocks);
	    while(*dctStatus==1)
	    {
		    pr_info("Running DCT\n");
	    }
	    pr_info("Completed DCT\n");
        }
        case IOCTL_DCTWAIT:
	{
            while(*dctStatus==1)
	    {
		    pr_info("Running DCT\n");
	    }
	    pr_info("Completed DCT\n");
            break;
        }
        case IOCTL_DCTOUTPUTDATA:
        {

            int readError = copy_to_user((int16_t*)arg,(int16_t*)outImageDataDMAcpu,outImageDataByteSize);   
            if(readError)
                pr_err("DCT Driver Error: Copy from DMA output memory failed\n");
	   
	    /*
	    pr_info("Read %d bytes to out image\n",outImageDataByteSize);
	    pr_info("Data %d\n",*((int16_t*)outImageDataDMAcpu));
	    */
	    break;
        }
        case IOCTL_DCTDMAFREE:
        {
            dma_free_coherent(dct_device.this_device,inImageMemByteSize,inImageMemDMAcpu,inImageMemDMAHandle);
            dma_free_coherent(dct_device.this_device,outImageMemByteSize,outImageMemDMAcpu,outImageMemDMAHandle);
            break;
        }
        case IOCTL_DCTSTATUS:
	{
	    pr_info("Dev status:%d\n",*dctStatus);
            int readError = copy_to_user((uint32_t*)arg,dctStatus,4);
            if(readError)
                pr_err("DCT Driver Error: Reading dct status failed\n");
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
    error = misc_register(&dct_device);
    if (error)
    {
        pr_err("Error: Register of adder driver failed\n");
        return error;
    }
   
    error = dma_set_coherent_mask(dct_device.this_device,DMA_BIT_MASK(31));
    if(error)
    {
        pr_err("Error: Device can not perform DMA with the given mask\n");
        return error;
    }
    
    dctBase = ioremap(ADDER_REGS_BASE_ADDR,5*ADDER_REGS_SIZE);
    if(dctBase==NULL)
    {
        pr_err("Error: Mapping of io memory failed\n");
        return error;
    }
    dctStatus = (uint32_t*) dctBase;
    dctInputAXIAddr = dctStatus + 1;
    dctOutputAXIAddr = dctInputAXIAddr + 1;
    dctNumBlocks = dctOutputAXIAddr + 1;
    dctExec = dctNumBlocks + 1;
    /*
    pr_info("dctStatus %X\n",(unsigned int*)dctStatus);
    pr_info("dctInputAXIAddr %X\n",(unsigned int*)dctInputAXIAddr);
    pr_info("dctOutputAXIAddr %X\n",(unsigned int*)dctOutputAXIAddr);
    pr_info("dctNumBlocks %X\n",(unsigned int*)dctNumBlocks);
    pr_info("dctExec %X\n",(unsigned int*)dctExec);
    */
    pr_info("DCT Device loaded\n");
    
    return 0;
}

static void __exit misc_exit(void)
{
    if(dctBase!=NULL)
    {
        iounmap(dctBase);
    }
    misc_deregister(&dct_device);
    pr_info("DCT Device unloaded\n");
}

module_init(misc_init)
module_exit(misc_exit)

MODULE_DESCRIPTION("Misc Driver for DCT");
MODULE_AUTHOR("Helge Meier");
MODULE_LICENSE("GPL");
