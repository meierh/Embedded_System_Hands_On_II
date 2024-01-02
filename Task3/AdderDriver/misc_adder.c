#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <asm/io.h>
#include "ioctl_adder.h"

#define ADDER_REGS_BASE_ADDR 0xA0000000
#define ADDER_REGS_END_ADDR 0xA0000FFF
#define ADDER_REGS_SIZE 4

static char* adderBase = NULL;
static int32_t* adderBaseInt32;

static long add_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
    //c = a + b
    int32_t* ab = (int32_t*)arg;
    int32_t* c = ((int32_t*)arg)+2;
    switch(cmd)
    {
        case IOCTL_ADD:
	    int writeError = copy_from_user(adderBaseInt32,ab,2);
	    if(writeError)
		    pr_error("Adder Error: Writing summands a and b failed\n");
	    int readError = copy_to_user(c,adderBaseInt32+2,1);
	    if(readError)
		    pr_error("Adder Error: Reading result c failed\n");
	    break;
	default:
	    return -ENOTTY;
    }
    return 0;
}

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
    return len; /* But we don't actually do anything with the data */
}

static const struct file_operations sample_fops = {
    .owner			= THIS_MODULE,
    .write			= sample_write,
    .open			= sample_open,
    .release		= sample_close,
    .unlocked_ioctl	= add_ioctl,
    .llseek 		= no_llseek,
};

struct miscdevice sample_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "misc_adder",
    .fops = &sample_fops,
};

static int __init misc_init(void)
{
    int error;

    error = misc_register(&sample_device);
    if (error)
    {
        pr_err("Error: Register of adder driver failed\n");
        return error;
    }

    adderBase = ioremap(ADDER_REGS_BASE_ADDR,3*ADDER_REGS_SIZE);
    if(adderBase==NULL)
    {
	pr_err("Error: Mapping of io memory failed\n");
	misc_exit();
	return error;
    }
    adderBaseInt32 = (*int32_t) adderBase;

    return 0;
}

static void __exit misc_exit(void)
{
    if(adderBase!=NULL)
    {
        iounmap(adderBase);
    }
    misc_deregister(&sample_device);
    pr_info("I'm out\n");
}

module_init(misc_init)
module_exit(misc_exit)

MODULE_DESCRIPTION("Misc Driver for Adder");
MODULE_AUTHOR("Helge Meier");
MODULE_LICENSE("GPL");
