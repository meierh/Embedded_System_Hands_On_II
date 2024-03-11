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
static int errorCode;

static long add_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
    //c = a + b
    int32_t* ab = (int32_t*)arg;
    int32_t* c = ((int32_t*)arg)+2;
    switch(cmd)
    {
        case IOCTL_ADD:
	    errorCode = copy_from_user(adderBaseInt32,ab,2);
	    if(errorCode)
		    pr_err("Adder Error: Writing summands a and b failed\n");
	    errorCode = copy_to_user(c,adderBaseInt32+2,1);
	    if(errorCode)
		    pr_err("Adder Error: Reading result c failed\n");
	    break;
	default:
	    return -ENOTTY;
    }
    return 0;
}

static const struct file_operations adder_fops = {
    .owner		= THIS_MODULE,
    .unlocked_ioctl	= add_ioctl
};

struct miscdevice adder_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "misc_adder",
    .fops = &adder_fops,
};

static void __exit misc_exit(void);

static int __init misc_init(void)
{
    errorCode = misc_register(&adder_device);
    if (errorCode)
    {
        pr_err("Error: Register of adder driver failed\n");
        return errorCode;
    }

    adderBase = ioremap(ADDER_REGS_BASE_ADDR,3*ADDER_REGS_SIZE);
    if(adderBase==NULL)
    {
	pr_err("Error: Mapping of io memory failed\n");
	misc_exit();
	return errorCode;
    }
    adderBaseInt32 = (int32_t*) adderBase;
    pr_info("Misc Adder Driver loaded\n");
    return 0;
}

static void __exit misc_exit(void)
{
    if(adderBase!=NULL)
    {
        iounmap(adderBase);
    }
    misc_deregister(&adder_device);
    pr_info("Misc Adder Driver unloaded\n");
}

module_init(misc_init)
module_exit(misc_exit)

MODULE_DESCRIPTION("Misc Driver for Adder");
MODULE_AUTHOR("Helge Meier");
MODULE_LICENSE("GPL");
