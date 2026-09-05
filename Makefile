NASM ?= nasm
CC = gcc
NASMFLAGS ?= -f elf64 -g -F dwarf
SDL_LIB ?= -l:libSDL2-2.0.so.0
LDLIBS = $(SDL_LIB) -l:libGL.so.1 -l:libEGL.so.1 -lm
OBJECTS = build/main.o build/gpu.o build/assets.o build/cpu.o build/cpu_text.o build/cpu_scale.o

.PHONY: all test snapshot install uninstall clean
all: build/jesussaves
build:
	mkdir -p build
build/background.bgra: assets/heaven-4k.png scripts/pack_background.py | build
	python3 scripts/pack_background.py
build/main.o: src/main.asm assets/turbulence.bin | build
	$(NASM) $(NASMFLAGS) -o $@ $<
build/gpu.o: src/gpu.asm shaders/scene.vert shaders/scene.frag | build
	$(NASM) $(NASMFLAGS) -o $@ $<
build/assets.o: src/assets.asm assets/text-sdf.bin build/background.bgra | build
	$(NASM) $(NASMFLAGS) -o $@ $<
build/cpu%.o: src/cpu%.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<
build/cpu.o: src/cpu.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<
build/jesussaves: $(OBJECTS)
	$(CC) -no-pie -Wl,-z,noexecstack $(LDFLAGS) -o $@ $(OBJECTS) $(LDLIBS)
snapshot: all
	./build/jesussaves --snapshot
test: all
	python3 tests/verify.py
install: all
	python3 scripts/install.py
uninstall:
	python3 scripts/install.py --uninstall
clean:
	python3 -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
