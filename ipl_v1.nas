

	CYLS	EQU	10
	ORG	0x7c00


	JMP	entry		;jump to entry。
	DB	0x90		
	DB	"HELLOIPL"	;启动区的名称，可以是任意字符，要求8字节（存疑）。
	DW	512		;每个secter的大小，必须为512字节。
	DB	1		;簇的大小，必须为1个扇区。簇：CLUST,由若干个扇区组成的一个单位，因为扇区太小，所以用簇这个概念能更加方便的管理。
	DW	1		;FAT的起始位置（一般从第一个扇区开始）(存疑，FAT是什么)。
	DB	2		;FAT的个数，必须为2（存疑，为什么）。
	DW	224		;文件目录数，一般设置为224。

	DW	2880		;该磁盘的大小（必须为2880扇区。解释：这里之所以是2880是因为软盘一共有80个柱面，每个柱面有18个扇区，磁头分上下两面，因此18*80*2=2880个柱面）。
	DB	0xf0		;磁盘的种类（必须是0xf0）。
	DW	9		;FAT的长度（必须是9个扇区）。
	DW	18		;1个磁道（track）有18个扇区（必须是）。

	DW	2		;磁头数，显然为2。
	DD	0		;不适用分区，因此这里是0。
	DD	2880		;重写一次磁盘大小（存疑，不知为何）。
	DB	0,0,0x29	;书中说意义不明，固定（存疑）。
	DD	0xffffffff	;（可能是卷标号码，存疑）。
	DB	"HELLO-OS   "	;磁盘的名称（要求11字节，不足需用空格补足）。
	DB	"FAT12   "	;磁盘格式名称（要求8字节，不足需用空格补足）。
	RESB	18		;先空出18字节。


entry:
	MOV	AX,0		;初始化工作，累加寄存器置零。
	MOV	SS,AX		;SS为stack segment栈段寄存器。
	MOV	SP,0x7c00	;SP为stack point栈指针寄存器。
	MOV	DS,AX		;DS为data segment数据段寄存器。

	MOV	AX,0x0820	;为累加寄存器赋值。
	MOV	ES,AX		;附加段寄存器extra segment。
	MOV	CH,0		;柱面号。
	MOV	CL,2		;扇区号。
	MOV	DH,0		;磁头号。

readloop:	
	MOV	SI,0		;source index，源变置寄存器。
retry:
	MOV	AH,0x02		;这里在为接下来调用中断机制做准备，为AH参数赋值，0x02在0x13中的意义为读盘。
	MOV	AL,1		;处理对象的扇区数，只能同时处理连续的扇区，这里为1。
	MOV	BX,0		;基址寄存器置为0。
	MOV	DL,0x00		;驱动器号，0x00代表的是A号驱动器。
	INT	0x13		;中断机制，但这里先按照函数调用来理解，调用BIOS的0x13号功能，用来读、写，扇区校验（verify），以及寻道（seek）。	
	JNC	next		;jump if not carry flag，上述函数会返回一个值，FLAG.CF==0则没有错误，FLAG.CF==1,有错误，错误号码存入AH内。
	ADD	SI,1		;SI += 1。
	CMP	SI,5		;比较SI和5。
	JAE	error		;jump if above or equal。
	MOV	AH,0x00		;将AH置空，让AH表达的意思重新置为没错错误，如果出现错误再对AH的值进行更改。
	MOV	DL,0x00		;重新将驱动器号设置为A号。
	INT	0x13		;重新调用BIOS的0x13号函数（存疑，有点多余，估计不是单纯的函数调用，可能起的是清空或者还原的作用吧）
	JMP	retry		;跳转到retry重新尝试读盘。

next:
	MOV	AX,ES		;把内存地址后移0x0020
	ADD	AX,0x0020
	MOV	ES,AX		;因为没有ADD ES,0x0020指令，所以这里稍微绕个弯。
	ADD	CL,1		;往CL里+1，到下一个扇区。
	CMP	CL,18		;如果CL=18
	JBE	readloop	;jump if below or equal如果CL<=18，跳转回readloop，好像忽然有点明白C语言里面的goto是怎么产生的了- -
	MOV	CL,1		;如果已经读了18个扇区了，把CL置为1
	ADD	DH,1		;磁头数+1，变成反面
	CMP	DH,2		;对比DH和2
	JB	readloop	;如果小于，DH < 2,跳转回readloop，继续读，直到读取完反面磁头的18个扇区为止，读完之后DH的值会=2，不满足小于的条件，往下走。
	MOV	DH,0		;把磁头号重新赋值为0，还原。
	ADD	CH,1		;CH += 1，也就是柱面号。
	CMP	CH,CYLS	;对比柱面号和预设的10个柱面
	JB	readloop	;如果小于就继续读，每个柱面有18*2个扇区，10个柱面总共读入了360个扇区的数据，360*512字节=184320字节。

	MOV	[0x0ff0],CH
	JMP	0xc200

error:
	MOV	SI,msg		;为SI赋值，标号msg为一个地址	
putloop:
	MOV	AL,[SI]		;累加寄存器赋值为内存地址在[SI]的值
	ADD	SI,1		;给SI+1
	CMP	AL,0		;比较
	JE	fin		;相等跳转到fin
	MOV	AH,0x0e		;否则将AH赋值为0x0e,在后面的调用中为显示一个文字的意思
	MOV	BX,15		;基址寄存器赋值为15，制定字符颜色
	INT	0x10		;调用显卡BIOS
	JMP	putloop
fin:
	HLT
	JMP	fin


msg:
	DB	0x0a, 0x0a	;直接写入两个换行符
	DB	"load error"	;读入装载错误的字符串
	DB	0x0a		;再写入一个换行符
	DB	0		;写入0

RESB	0x7dfe-$

	DB	0x55, 0xaa
