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
 mov ax, 0x10 ; GDT_idx
 mov ds, ax
 mov es, ax
 mov ss, ax
 ; ustawia rejestry na DS, jezeli tego nie zrobimy to niektore instrukcje korzystajace z tych rejestrow nie beda dzialac
 ;lea eax, [0xb8000]
 ;mov dword [eax], 0x4141413
 
 mov eax, (PML4 - $$) + 0x20000
 mov cr3, eax

 mov eax, cr4
 or eax, 1 << 5
 mov cr4, eax

 mov ecx, 0xc0000080 ; EFER - musimy to ustawic do long mode
 rdmsr ; wczytuje do eax wartosc z ecx
 or eax, 1 << 8 ; enable IA-32e - tryb 64-bitowy, emuluje 32-bitowy 
 wrmsr 

 ; za;aczamy paging
 mov eax, cr0
 or eax, 1 << 31
 mov cr0, eax
 
 lgdt [GDT64_addr + 0x20000]
 jmp dword 0x8:(0x20000+start64)

start64:
 [bits 64]
 ;sprawdzic czy to jest ok
 mov ax, 0x10 ; GDT_idx
 mov ds, ax
 mov es, ax
 mov ss, ax
 ;loading kernel
 ;0x20 bo to program table offset w naglowku elf - w tym jest nasz skompilowany plik w c
loader:
 ; lea - laduje konkretna komorke - forma segment:offset, tutaj adres fizyczny
 lea rsi, [0x20000 + kernel + 0x20] ; ph offset w file headerze
 add rsi, 0x20000 + kernel ; ustawiamy ph wartosc phoff na rzeczywisty adres kernela. Offset od poczatku pliku a origin niestety w 0x00000 :)
 ; mov zero extended word - dwa bajty
 movzx ecx, word [0x20000 + kernel + 0x38] ; ilosc headerow od elfa, jak jest load to ladujemy
 
 cld ; flaga procesora - mowi czy rep movsb ma kopiowac w gore czy w dol, chcemy w gore 
 ; kropka - etykieta lokalna - nie piszemy wtedy loader.phloop
 .ph_loop:
 mov eax, [rsi+0] ; czemu +0?

 cmp eax, 1 ; chcemy p-type w program headerze elfa byl rowny pt_load, wtedy chcemy zaladowac binarke w pamiec  
 jne .next

 ; ladowanie headera by go przekopiowac 
 mov r8d, [rsi+8] ; offset, vaddr, filesz
 mov r9d, [rsi+0x10] ; vadress ale w sumie narazie rowny pamieci fizycznej, tam kopiujemy dane
 mov r10d, [rsi+0x20] ; po reboocie moze sie okazac ze tu cos bedzie, musimy to wyczyscic jak nie bedzie dzialac  
 
 mov rbp, rsi ; zamiast dawac na stos dajemy do rejestru, szybsze, stosu i tak nie uzywamy duzo, rejestru tego tez nie
 mov r15, rcx ; nie obciazamy tak cache procesora robiac stos. Oczywiscie robimy tak dlatego, ze rcx uzywamy w loopie jako licznik a rsi to byl ph offset

 lea rsi, [0x20000 + kernel + r8d]
 mov rdi, r9
 mov rcx, r10 
 rep movsb ; kopia danych, kopiujemy binarke

 mov rsi, rbp
 mov rcx, r15
 .next:
 add rsi, 0x20 ; pomijamy header
 loop .ph_loop
 
 mov rsp, 0x30f000 ; ustawiamy stos pod tym adresem
 mov rax, [0x20000 + kernel + 0x18] ; ustawiamy na na entry point (witamy w c) 
 
 ; mov rax, 0xb8000
 ; mov rdx, 0x4141414141414141
 ; mov [rax], rdx
call rax

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

; GDT 64-bit
GDT64_addr:
dw (GDT_end - GDT) - 1 ; zakladamy, ze GDT ma rozmiar 2^n - tak otrzymamy maske 111...111
dd 0x20000 + GDT

times (32 - ($-$$) % 32) db 0xcc
GDT64:

dd 0, 0
; tu bedziemy robili segment descriptor - co tam sie daje to manual intela (stream #2), dla kernela or 0 - nic nie dajemy
; subtelne roznice dla 64b - musimy ogarnac bity L i D/B, poza tym to samo (stream #3)
; CS
dd 0xffff ; segment limit
dd (10 << 8) | (1 << 12) | (1 << 15) | (0xf << 16) | (1 << 21) | (1 << 23)

; DS
dd 0xffff ; segment limit
dd (2 << 8) | (1 << 12) | (1 << 15) | (0xf << 16) | (1 << 21) | (1 << 23)


GDT64_end:

times (4096 - ($-$$) % 4096) db 0 
; to potrzebne do stronnicowania, defacto tych $$ mogloby nie byc bo $$ to origin
PML4:
dq 3 | (PDPTE - $$ + 0x20000)
times 511 dq 0 

; page directory pointer
PDPTE:
dq 3 | (1 << 7)
times 511 dq 0 



times (512 - ($-$$) % 512) db 0 
; kernel ma adres 0x23200h
kernel:

