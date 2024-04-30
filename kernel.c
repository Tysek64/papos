void _start(void) {
 short* addr = (short*)0xB8000;
 unsigned char attribute = 0x0F;
 char* string = "Hello World!";
 for (int i = 0 ; i < 12 ; ++i)
 {
	 *addr = (attribute << 8) | string[i];
	 ++addr;
 }

 for (;;) {}
}
