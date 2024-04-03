[bits 16]
[org 0x7c00]

jmp word 0x0000:start

start:
 ; load stage2, DL is set automatically
 mov ax, 0x2000
 mov es, ax
 xor bx, bx ; zerowanie
 
 mov ah, 2 ; patrz ctyme ralph brown interrupt 13 - chcemy wczytac pamiec dyskietki do biosa
 mov al, 0xcc ; roboczo, builder nam podmieni automatycznie ilosc sektorow, zeby stage sie zmiescil
 nop
 nop
 mov ch, 0 ; numer cylindra - dyskietki chyba nie maja
 mov cl, 2 ; sektory liczymy od 1
 mov dh, 0 ; numer glowicy
 
 int 13h
 jmp word 0x2000:0x0000 ; tu rezyduje stage 2!

epilogue:
%if ($ - $$) > 510
 $fatal "Bootloader code exceeds 512 bytes"
%endif


times 510 - ($ - $$) db 0
db 0x55
db 0xAA
