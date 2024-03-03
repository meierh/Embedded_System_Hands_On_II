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

static uint64_t inputImageSize;
static dma_addr_t inputDMAHandle;
void* inputDMAcpu;

static uint64_t outputImageSize;
static dma_addr_t outputDMAHandle;
void* outputDMAcpu;

static char* dctBase = NULL;
static uint64_t* dctStatus;
static uint64_t* dctInputAddr;
static uint64_t* dctOutputAddr;
static uint64_t* dctNumBlocks;
static uint64_t* dctExec;


static long dct_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
    switch(cmd)
    {
        case IOCTL_DCTSTATUS:
        {
            int readError = copy_to_user((uint64_t*)arg,dctStatus,1);
            if(readError)
                pr_err("DCT Driver Error: Reading dct status failed\n");
            break;
        }
        case IOCTL_DCTINPUTSIZE:
        {
            int writeError = copy_from_user(&inputImageSize,(uint64_t*)arg,1);   
            if(writeError)
                pr_err("DCT Driver Error: Writing input image size failed\n");
            break;
        }
        case IOCTL_DCTINPUTDATA:
        {
            int writeError = copy_from_user((uint8_t*)inputDMAcpu,(uint8_t*)arg,inputImageSize);   
            if(writeError)
                pr_err("DCT Driver Error: Copy to DMA input memory failed\n");
            dma_sync_single_for_device(&dct_device,&inputDMAHandle,inputImageSize,DMA_TO_DEVICE);
            break;
        }
        case IOCTL_DCTOUTPUTSIZE:
        {
            int writeError = copy_from_user(&outputImageSize,(uint64_t*)arg,1);   
            if(writeError)
                pr_err("DCT Driver Error: Writing output image size failed\n");
            break;
        }
        case IOCTL_DCTOUTPUTDATA:
        {
            int readError = copy_to_user((uint8_t*)arg,(uint8_t*)outputDMAcpu,outputImageSize);   
            if(readError)
                pr_err("DCT Driver Error: Copy from DMA output memory failed\n");
            dma_sync_single_for_cpu(&dct_device,outputDMAHandle,outputImageSize,DMA_FROM_DEVICE);
            break;
        }
        case IOCTL_DCTDMAMALLOC:
        {
            inputDMAcpu = dma_alloc_coherent(&dct_device,inputImageSize,&inputDMAHandle,GFP_KERNEL);
            if(inputDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of input image dma failed\n");
            outputDMAcpu = dma_alloc_coherent(&dct_device,outputImageSize,outputDMAHandle,GFP_KERNEL);
            if(outputDMAcpu==NULL)
                pr_err("DCT Driver Error: Allocation of output image dma failed\n");
            
            //dctInputAddr = 
            //dctOutputAddr = 
            break;
        }
        case IOCTL_DCTDMAFREE:
        {
            dma_free_coherent(&dct_device,inputImageSize,inputDMAcpu,inputDMAHandle);
            dma_free_coherent(&dct_device,outputImageSize,outputDMAcpu,outputDMAHandle);
            break;
        }
        case IOCTL_DCTNUMBLOCKS:
        {            
            int writeError = copy_from_user(dctNumBlocks,(uint64_t*)arg,1);
            if(writeError)
                pr_err("DCT Driver Error: Writing number of blocks failed\n");
            break;
        }
        case IOCTL_DCTEXECCMD:
        {
            *dctExec = 1;
            break;
        }
	default:
	    return -ENOTTY;
    }
    return 0;
}

/*
static int sample_open(struct inode *inode, struct file *file)
{
    pr_info("I have been awoken\n");
    return 0;
}

static int sample_close(struct inode *inodep, struct file *filp)
{
    pr_info("Sleepy time\n");
    return 0;
}

static ssize_t sample_write(struct file *file, const char __user *buf,
		       size_t len, loff_t *ppos)
{
    pr_info("Yummy - I just ate %d bytes\n", len);
    return len; 
}
*/

static const struct file_operations dct_fops = {
    .owner			= THIS_MODULE,
    /*
    .write			= sample_write,
    .open			= sample_open,
    .release		= sample_close,
    */
    .unlocked_ioctl	= dct_ioctl
    /*,
    .llseek 		= no_llseek,
    */
};

struct miscdevice dct_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "misc_dct",
    .fops = &dct_fops,
};

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

    dctBase = ioremap(ADDER_REGS_BASE_ADDR,5*ADDER_REGS_SIZE);
    if(dctBase==NULL)
    {
        pr_err("Error: Mapping of io memory failed\n");
        misc_exit();
        return error;
    }
    dctStatus = (uint64_t*) dctBase;
    dctInputAddr = dctStatus + 1;
    dctOutputAddr = dctInputAddr + 1;
    dctNumBlocks = dctOutputAddr + 1;
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
