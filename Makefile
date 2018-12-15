all: menu

menu: menu.asm
	acme --cpu 6510 menu.asm
