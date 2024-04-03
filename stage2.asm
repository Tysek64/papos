[bits 16]
[org 0x0000]

start:
 mov ax, 0x2000
 mov ds, ax
 mov es, ax

 mov ax, 0x1f00
 mov ss, ax
 xor sp, sp

 ; to be removed 
 ; mov ax, 0xb800 ; tu zaczyna sie vram
 ; mov fs, ax
 ; mov bx, 0
 ; mov ax, 0x4141
 ; mov [fs:bx], ax

 mov al, 0x13 
 mov ah, 0
 int 16

 cli
 lgdt [GDT_addr]
 
 mov eax, cr0 ; standardowa praktyka - czesto na flagach operacji nie wykonujemy, zamiast tego dajemy je do rejestru i wtedy
 or eax, 0x1
 mov cr0, eax
 mov ax, DATA_SEG
 mov ds, ax

 jmp dword 0x8:(0x20000+start32) ; dopoki tego skoku nie ma to bedziemy pracowac w 16 bitach, cache z 16 bitowym kodem sie kasuje
 ; 0x8 to adres CS w naszym GDT - jeden segment ma 32 bity na informacje i 32 na segment limit - razem 64/8 = 8 bajtow
 
start32:
 [bits 32]
 mov ax, 0x10
 mov ds, ax
 mov es, ax
 mov ss, ax
 ; czyscimy rejestry, jezeli tego nie zrobimy to niektore instrukcje korzystajace z tych rejestrow nie beda dzialac
 call papos

jmp $

GDT_addr:
 dw (GDT_end - GDT) - 1 ; zakladamy, ze GDT ma rozmiar 2^n - tak otrzymamy maske 111...111
 dd 0x20000 + GDT

 times (32 - ($-$$) % 32) db 0xcc

; GLOBAL DESCRIPTOR TABLE, 32-bit
GDT:

 GDT_null:
  dq 0
; tu bedziemy robili segment descriptor - co tam sie daje to manual intela (stream #2), dla kernela or 0 - nic nie dajemy

; CS
 GDT_code:
  dw 0xffff ; segment limit
  dw 0
  
  dd (10 << 8) | (1 << 12) | (1 << 15) | (0xf << 16) | (1 << 22) | (1 << 23)

; DS
 GDT_data:
  dw 0xffff
  dw 0

  dd (2 << 8) | (1 << 12) | (1 << 15) | (0xf << 16) | (1 << 22) | (1 << 23)

GDT_end:

CODE_SEG equ GDT_code - GDT
DATA_SEG equ GDT_data - GDT

papos:
 mov cx, 64000
 mov edi, 0x0A0000
 mov al, 0
paint:
 mov [edi], al
 inc al
 dec cx
 inc edi
 jcxz end
 jmp paint
end:
 jmp $

times 1337 db 0x41

