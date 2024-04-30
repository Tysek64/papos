import subprocess
import os

def fix_stage1_size():
    stage2_size = os.stat("stage2").st_size
    kernel_size = os.stat("kernel64").st_size

    stage2_size = (int)((stage2_size+kernel_size+511)/512)

    if stage2_size >= 255:
        print("stage2 & kernel size: ")
        print(stage2_size+kernel_size)
        raise Exception("\nstage2 & kernel size are too large")

    with open("stage1", "rb+") as f:
        d = f.read() #maly plik wiec mozna
        idx = d.index(b"\xb0\xcc\x90\x90") #chcemy podmienic cc na ilosc segmentow pamieci
        d = bytearray(d)
        d[idx+1] = stage2_size
        f.seek(0)
        f.write(d) #na dysku zapisywany jest i tak caly plik mniejszy niz 512 bajtow - a system i tak nie moze zmienic pojedynczego bajtu, tylko sektor - i tak nadpisuje caly plik.

cmds = ["gcc kernel.c -std=c99 -nostdlib -o kernel64", 
        "strip kernel64", 
        "nasm stage1.asm", 
        "nasm stage2.asm", 
        fix_stage1_size]
files_to_img = ["stage1", "stage2", "kernel64"] #tu kernel jest doklejany za stage2

for cmd in cmds:
    if type(cmd) is str:
        print("Running: " + cmd)
        print(subprocess.check_output(cmd, shell=True))
    else:
        print("Calling: " + cmd.__name__)
        cmd()

buf = []
for fn in files_to_img:
    with open(fn, "rb") as f:
        d = f.read()
        buf.append(d)

        if len(d)%512 == 0:
            continue

        padding_size = 512 - (len(d) % 512)
        buf.append(b"\0"*padding_size)

#problem?
with open("floppy.bin", "wb") as f:
    f.write(b''.join(buf))
