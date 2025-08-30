all: out/final.bin out/final.txt out/final.mem

# Replace this with the name of your riscv toolchain here:
PREFIX := riscv32-unknown-elf

TARGET_RISCV_ARCH := rv32ec_zicond_zbs
TARGET_RISCV_ABI  := ilp32e

# GCC options
GCC_ARCH_ARGS := -march=$(TARGET_RISCV_ARCH) -mabi=$(TARGET_RISCV_ABI)
GCC_MODE_ARGS := -ffreestanding -nostdlib -nostdlib -fno-pic -no-pie
GCC_LINK_ARGS := -T link.lds -mcmodel=medlow
GCC_OPTM_ARGS := -fwhole-program -Oz -flto -mbranch-cost=2
GCC_WARN_ARGS := -Wall -Wextra -pedantic
GCC_ARGS = $(GCC_ARCH_ARGS) $(GCC_MODE_ARGS) $(GCC_WARN_ARGS) $(GCC_LINK_ARGS) $(GCC_OPTM_ARGS)

# List your sources here
SOURCE_FILES := src/test.c
SOURCE_FILES += src/startup.S

HEADER_FILES := src/platform.h



out/final.bin: out/final.o
	riscv-none-elf-objcopy -O binary out/final.o out/final.bin

out/final.txt: out/final.o
	$(PREFIX)-objdump -Mnumeric,no-aliases -dr out/final.o > out/final.txt

out/final.o: $(SOURCE_FILES) $(HEADER_FILES) link.lds
	$(PREFIX)-gcc $(GCC_ARGS) -lgcc $(SOURCE_FILES) -o out/final.o -lgcc

out/final.mem: out/final.o
	$(PREFIX)-objcopy -O verilog out/final.o out/final.mem

.PHONY: clean cleantmp copy

setup:
	mkdir -p out

clean:
	rm -f out/final.bin out/final.txt out/final.o out/final.mem
