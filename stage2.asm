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
 mov esp, 0x300000 ; dla inicjalizacji stosu
 ; ustawia rejestry na DS, jezeli tego nie zrobimy to niektore instrukcje korzystajace z tych rejestrow nie beda dzialac
 ;lea eax, [0xb8000]
 ;mov dword [eax], 0x4141413
  
 call LONG_MODE_CHECK
 call A20_CHECK
 mov eax, (PML4 - $$) + 0x20000
 mov cr3, eax

 mov eax, cr4
 or eax, 1 << 5
 mov cr4, eax

 mov ecx, 0xC0000080 ; EFER - musimy to ustawic do long mode
 rdmsr ; wczytuje do eax wartosc z ecx
 or eax, 1 << 8 ; enable IA-32e - tryb 64-bitowy, emuluje 32-bitowy 
 wrmsr 

 ; zalaczamy paging
 mov eax, cr0
 or eax, 1 << 31
 mov cr0, eax 
 lgdt [GDT64_addr + 0x20000]
 jmp dword 0x8:(0x20000+start64)

LONG_MODE_CHECK:
 ; Check if CPUID is supported by attempting to flip the ID bit (bit 21) in
    ; the FLAGS register. If we can flip it, CPUID is available.
 
    ; Copy FLAGS in to EAX via stack
    pushfd
    pop eax
 
    ; Copy to ECX as well for comparing later on
    mov ecx, eax
  
    ; Flip the ID bit
    xor eax, 1 << 21

    ; Copy EAX to FLAGS via the stack
    push eax
    popfd
  
    ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax
 
    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit
    ; back if it was ever flipped).
    push ecx
    popfd
 
    ; Compare EAX and ECX. If they are equal then that means the bit wasn't
    ; flipped, and CPUID isn't supported.
    xor eax, ecx
    jz .NoCPUID
    ; check cpuid extended functions
    xor eax, eax    
    mov eax, 0x80000000    ; Set the A-register to 0x80000000.
    cpuid                  ; CPU identification.
    cmp eax, 0x80000001    ; Compare the A-register with 0x80000001.
    jb .NoLongMode         ; It is less, there is no long mode.
    ; test for long mode
    mov eax, 0x80000001    ; Set the A-register to 0x80000001.
    cpuid                  ; CPU identification.
    test edx, 1 << 29      ; Test if the LM-bit, which is bit 29, is set in the D-register.
    jz .NoLongMode         ; They aren't, there is no long mode.
    ret


    .NoCPUID:
    lea eax, [0xb8000]
    mov dword [eax], 0x4141413
    mov eax, 0x0 ; CPUID not available dla cpu duo2core - jest dostepny CPUID
    jmp $
    .NoLongMode: 
    lea eax, [0xb8000]
    mov dword [eax], 0x4141413
    mov eax, 0x1 ; No long mode available - dla duo2core dziala - dla 486 nie
    jmp $

A20_CHECK:
 pushad ; pushuje GPRy na stos - calkiem przydatne
 mov edi,0x112345  ;odd megabyte address.
 mov esi,0x012345  ;even megabyte address.
 mov [esi],esi     ;making sure that both addresses contain diffrent values.
 mov [edi],edi     ;(if A20 line is cleared the two pointers would point to the address 0x012345 that would contain 0x112345 (edi)) 
 cmpsd             ;compare addresses to see if the're equivalent.
 popad
 je .A20_OFF        
 ret               ;if not equivalent , the A20 line is cleared.
.A20_OFF: 
   lea eax, [0xb8000]
   mov dword [eax], 0x4141413
   mov eax, 0x2 ; A20 jest wylaczona, dla core2duo dziala
   jmp $
start64:
[bits 64]
 ;sprawdzic czy to jest ok
 mov ax, 0x10 ; GDT data segment
 mov ds, ax
 mov es, ax
 mov ss, ax
 ; do tego momentu dziala, sukces 64 bit

 ;loading kernel
 ;0x20 bo to program table offset w naglowku elf - w tym jest nasz skompilowany plik w c
loader:
 ; lea - laduje konkretna komorke - forma segment:offset, tutaj adres fizyczny
 mov rsi, [0x20000 + kernel + 0x20] ; ph offset w file headerze
 add rsi, 0x20000 + kernel
 ; ustawiamy ph wartosc phoff na rzeczywisty adres pliku elfa. Offset od poczatku pliku a origin niestety w 0x00000 :)
 ; jednak pamiec gynvaela mylila
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
 add r9d, 0x3ff000
 mov r10d, [rsi+0x20] ; po reboocie moze sie okazac ze tu cos bedzie, musimy to wyczyscic jak nie bedzie dzialac  
 
 mov rbp, rsi ; zamiast dawac na stos dajemy do rejestru, szybsze, stosu i tak nie uzywamy duzo, rejestru tego tez nie
 mov r15, rcx ; nie obciazamy tak cache procesora robiac stos. Oczywiscie robimy tak dlatego, ze rcx uzywamy w loopie jako licznik a rsi to byl ph offset

 lea rsi, [0x20000 + kernel + r8d]
 mov rdi, r9
 mov rcx, r10
 ; call BLUE_SCREEN
 rep movsb ; kopia danych, kopiujemy binarke

 mov rsi, rbp
 mov rcx, r15
 .next:
 add rsi, 0x38 ; pomijamy header
 loop .ph_loop
 
 mov rsp, 0x30f000 ; ustawiamy stos pod tym adresem
 mov rax, [0x20000 + kernel + 0x18] ; ustawiamy na na entry point (witamy w c) 
 ; add rax, 0x3ff000 ; znow korekta do coldwinda 
 ;5x0 i 4 
 ; mov rax, 0xb8000
 ; mov rdx, 0x4141414141414141
 ; mov [rax], rdx
add rax, 0x3ff000 ; korekta
call rax


BLUE_SCREEN:                           ; Clear the interrupt flag.
    mov ax, 0x10            ; Set the A-register to the data descriptor.
    mov ds, ax                    ; Set the data segment to the A-register.
    mov es, ax                    ; Set the extra segment to the A-register.
    mov fs, ax                    ; Set the F-segment to the A-register.
    mov gs, ax                    ; Set the G-segment to the A-register.
    mov ss, ax                    ; Set the stack segment to the A-register.
    mov edi, 0xB8000              ; Set the destination index to 0xB8000.
    mov rax, 0x1F201F201F201F20   ; Set the A-register to 0x1F201F201F201F20.
    mov ecx, 500                  ; Set the C-register to 500.
    rep stosq                     ; Clear the screen.
    ret                           ; Halt the processor.

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
dw (GDT_end - GDT64) - 1 ; zakladamy, ze GDT ma rozmiar 2^n - tak otrzymamy maske 111...111
dd 0x20000 + GDT64

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
dq 1 | (1 << 1) | (PDPTE - $$ + 0x20000)
times 511 dq 0 

; page directory pointer
PDPTE:
dq 1 | (1 << 1) | (1 << 7)
times 511 dq 0 



times (512 - ($-$$) % 512) db 0 
; kernel ma adres 0x23200h
kernel:

