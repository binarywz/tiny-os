	#include "os.h"

	// 声明本地以下符号是全局的,在其它源文件中可以访问
	.global _start

	// 指定以下的代码生成16位的机器指令,这样才能在启动时的实模式下运行
  .code16

	// 以下是代码区
 	.text
_start:
	// x86使用段寄存器中的内容作为内存访问的基址,因此以下预先设置好
	mov $0, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %ss
	mov $_start, %esp		// 设置栈的起始地址

	// 计算机上电启动后,只取512字节到0x7c00处,即相当于自己只有个头在内存
	// 将自己的其余部分读取到0x7E00处,即0x7c00的后512字节
read_self_all:
	mov $_start_32, %bx // $_start_32即0x7e00
	// 读取磁盘
	mov $0x2, %cx
	mov $0x240, %ax
	mov $0x80, %dx
	int $0x13        // 调用BIOS函数读取代码
	jc read_self_all // 读取失败则重新读，判断EFLAGS寄存器CF位

	// 进入保护模式
	cli // 关闭中断
	lgdt gdt_desc	  // 加载描述符表
	mov $1, %eax
	lmsw %ax				// 设置PE位，进入保护模式
	jmp $KERNEL_CODE_SEG, $_start_32	// 进入32位保护模式代码，可以运行32位指令

	jmp .

	// 跳到引导标志, 由bios在上电后检查
	.org 0x1fe					// 引导标志,指定后面代码放在510位置处
	.byte 0x55, 0xaa    // usigned char s[] = {0x55, 0xaa}

	// 32位保护模式，位于512字节后
	.code32
	.text

// 0x7c00+0x200=0x7e00，0x200=512
_start_32:
	// 重新加载数据段寄存器
	mov $KERNEL_DATA_SEG, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %ss
	mov $_start, %esp

	// 跳转到c语言中运行
	call os_init

	// 打开分页机制
	mov $pg_dir, %eax
	mov %eax, %cr3

	mov %cr4, %eax
	orl $(1 << 4), %eax			// PSE位，支持4MB分页
	mov %eax, %cr4

	mov %cr0, %eax
	orl $(1 << 31), %eax		// 打开PG位，开启分页机制
	mov %eax, %cr0

	jmp .

gdt_desc:
	.word (256*8)-1  // 全局描述符表界限
	.long gdt_table  // 全局描述符表地址