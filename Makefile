CFLAGS+=-pedantic -Wall -Wextra -Werror $(shell pkg-config --cflags libnotify)
LDFLAGS=$(shell pkg-config --libs libnotify)

WANT_SD_NOTIFY=1
HAS_LIBSYSTEMD=$(shell pkg-config libsystemd && echo 1 || echo 0)

ifeq ($(HAS_LIBSYSTEMD),0)
$(warning libsystemd not found, setting WANT_SD_NOTIFY=0)
WANT_SD_NOTIFY=0
endif

ifeq ($(WANT_SD_NOTIFY),1)
CFLAGS+=-DWANT_SD_NOTIFY $(shell pkg-config --cflags libsystemd)
LDFLAGS+=$(shell pkg-config --libs libsystemd)
endif

SOURCES=$(wildcard *.c)
EXECUTABLES=$(patsubst %.c,%,$(SOURCES))

all: $(EXECUTABLES)

%: %.c
	$(CC) $(CFLAGS) $< -o $@ $(LIBS) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) $< -c -o $@

%: %.o
	$(CC) $< -o $@ $(LIBS) $(LDFLAGS)

# Noisy clang build that's expected to fail, but can be useful to find corner
# cases.
clang-everything: CC=clang
clang-everything: CFLAGS+=-Weverything -Wno-disabled-macro-expansion -Wno-padded -Wno-unused-macros
clang-everything: all

sanitisers: CC=gcc
sanitisers: CFLAGS+=-fsanitize=address -fsanitize=undefined
sanitisers: debug

debug: CFLAGS+=-Og -ggdb -fno-omit-frame-pointer
debug: all

fuzz-configs: CC=afl-gcc
fuzz-configs: CFLAGS+=-DWANT_FUZZER
fuzz-configs: export AFL_HARDEN=1
fuzz-configs: debug
	mkdir -p fuzz/configs/generated
	XDG_CONFIG_DIR=fuzz/configs/generated FUZZ=1 afl-fuzz -i fuzz/configs/testcases -o fuzz/configs/results -f fuzz/configs/generated/psi-notify ./psi-notify

fuzz-pressures: CC=afl-gcc
fuzz-pressures: CFLAGS+=-DWANT_FUZZER
fuzz-pressures: export AFL_HARDEN=1
fuzz-pressures: debug
	mkdir -p fuzz/pressures/generated
	XDG_CONFIG_DIR=fuzz/pressures/generated FUZZ=1 FUZZ_PRESSURE_PATH=fuzz/pressures/generated/pressures afl-fuzz -i fuzz/pressures/testcases -o fuzz/pressures/results -f fuzz/pressures/generated/pressures ./psi-notify

clang-tidy:
	clang-tidy psi-notify.c -checks=-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling -- $(CFLAGS) $(LDFLAGS)

clean:
	rm -f $(EXECUTABLES)
