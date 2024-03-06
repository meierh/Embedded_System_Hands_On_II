#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
/*#include <asm/io.h>*/
#include <linux/dma-mapping.h>
#include "ioctl_dct.h"

#define ADDER_REGS_BASE_ADDR 0xA0000000
#define ADDER_REGS_END_ADDR 0xA0000FFF
#define ADDER_REGS_SIZE 4

static uint32_t inputImageByteSize;
static dma_addr_t inputDMAHandle;
void* inputDMAcpu;

static uint32_t outputImageByteSize;
static dma_addr_t outputDMAHandle;
void* outputDMAcpu;

static char* dctBase = NULL;
static uint32_t* dctStatus;
static uint32_t* dctInputAXIAddr;
static uint32_t* dctOutputAXIAddr;
static uint32_t* dctNumBlocks;
static uint32_t* dctExec;

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
            int writeError = copy_from_user(dctNumBlocks,(uint32_t*)arg,1);
            if(writeError)
                pr_err("DCT Driver Error: Writing number of blocks failed\n");
            inputImageByteSize = (*dctNumBlocks)*64;
            outputImageByteSize = (*dctNumBlocks)*64*2;
            break;
        }
        case IOCTL_DCTDMAMALLOC:
        {
            inputDMAcpu = dma_alloc_coherent(dct_device.this_device,inputImageByteSize,&inputDMAHandle,GFP_KERNEL);
            if(inputDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of input image dma failed\n");
            outputDMAcpu = dma_alloc_coherent(dct_device.this_device,outputImageByteSize,&outputDMAHandle,GFP_KERNEL);
            if(outputDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of output image dma failed\n");
            *dctInputAXIAddr = (uint32_t) inputDMAHandle;
            *dctOutputAXIAddr = (uint32_t) outputDMAHandle;
            break;
        }
        case IOCTL_DCTINPUTDATA:
        {
            int writeError = copy_from_user((uint8_t*)inputDMAcpu,(uint8_t*)arg,inputImageByteSize);   
            if(writeError)
                pr_err("DCT Driver Error: Copy to DMA input memory failed\n");
            //dma_sync_single_for_device(dct_device.this_device,inputDMAHandle,inputImageByteSize,DMA_TO_DEVICE);
            break;
        }
        case IOCTL_DCTEXECCMD:
        {
            *dctExec = 1;
            break;
        }
        case IOCTL_WAIT:
        {
            while(*dctStatus==1)
            {
            }
            break;
        }
        case IOCTL_DCTOUTPUTDATA:
        {
            int readError = copy_to_user((uint8_t*)arg,(uint8_t*)outputDMAcpu,outputImageByteSize);   
            if(readError)
                pr_err("DCT Driver Error: Copy from DMA output memory failed\n");
            //dma_sync_single_for_cpu(dct_device.this_device,outputDMAHandle,outputImageByteSize,DMA_FROM_DEVICE);
            break;
        }
        case IOCTL_DCTDMAFREE:
        {
            dma_free_coherent(dct_device.this_device,inputImageByteSize,inputDMAcpu,inputDMAHandle);
            dma_free_coherent(dct_device.this_device,outputImageByteSize,outputDMAcpu,outputDMAHandle);
            break;
        }
        case IOCTL_DCTSTATUS:
        {
            int readError = copy_to_user((uint32_t*)arg,dctStatus,1);
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
    
    error = dma_set_coherent_mask(dct_device.this_device,DMA_BIT_MASK(32));
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
