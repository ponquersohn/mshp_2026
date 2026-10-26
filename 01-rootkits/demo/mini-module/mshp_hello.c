// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/module.h>
#include <linux/printk.h>

/* Module data: a character array that remains until unload. */
static const char message[] = "hello from kernel space";

/* Called once during loading. Returning 0 means initialization succeeded. */
static int __init mshp_hello_init(void)
{
	pr_info("mshp_hello: %s\n", message);
	return 0;
}

/* Called during normal unloading; real modules release resources here. */
static void __exit mshp_hello_exit(void)
{
	pr_info("mshp_hello: goodbye from kernel space\n");
}

/* Register entry/exit functions: this module has no user-space main(). */
module_init(mshp_hello_init);
module_exit(mshp_hello_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("MSHP teaching example: minimal logging module");
