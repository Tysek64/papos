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
 lgdt [GDT_addr]
 cli
 mov eax, cr0 ; standardowa praktyka - czesto na flagach operacji nie wykonujemy, zamiast tego dajemy je do rejestru i wtedy
 or eax, 1
 mov cr0, eax
 jmp dword 0x8:(0x20000+start32) ; dopoki tego skoku nie ma to bedziemy pracowac w 16 bitach, cache z 16 bitowym kodem sie kasuje
 ; 0x8 to adres CS w naszym GDT - jeden segment ma 32 bity na informacje i 32 na segment limit - razem 64/8 = 8 bajtow
 
start32:
 [bits 32]
 mov ax, 0x10
 mov ds, ax
 mov es, ax
 mov ss, ax
 ; ustawia rejestry na DS, jezeli tego nie zrobimy to niektore instrukcje korzystajace z tych rejestrow nie beda dzialac
 lea eax, [0xb8000]
 mov dword [eax], 0x4141413
 jmp $

GDT_addr:
dw (GDT_end - GDT) - 1 ; zakladamy, ze GDT ma rozmiar 2^n - tak otrzymamy maske 111...111
dd 0x20000 + GDT

times (32 - ($-$$) % 32) db 0xcc
; GLOBAL DESCRIPTOR TABLE, 32-bit
GDT:

dd 0, 0
; tu bedziemy robili segment descriptor - co tam sie daje to manual intela (stream #2), dla kernela or 0 - nic nie dajemy

; CS
dd 0xffff ; segment limit
dd (10 << 8) | (1 << 12) | (1 << 15) | (0xf << 16) | (1 << 22) | (1 << 23)

; DS
dd 0xffff ; segment limit
dd (2 << 8) | (1 << 12) | (1 << 15) | (0xf << 16) | (1 << 22) | (1 << 23)


GDT_end:

times 1337 db 0x41

