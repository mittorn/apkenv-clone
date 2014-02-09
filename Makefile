
# Android Gingerbread linker
LINKER_SOURCES=$(wildcard linker/*.c)

# Compatibility wrappers and hooks
COMPAT_SOURCES=$(wildcard compat/*.c)

# Library for getting files out of .apk files
APKLIB_SOURCES=$(wildcard apklib/*.c)

# Our own JNI environment implementation
JNIENV_SOURCES=$(wildcard jni/*.c)

# Support modules for specific applications
MODULES_SOURCES=$(wildcard modules/*.c)

# JPEG and PNG loaders
IMAGELIB_SOURCES=$(wildcard imagelib/*.c)

# segfault catch
DEBUG_SOURCES=$(wildcard debug/*.c)

TARGET = apkenv

DESTDIR ?= /
PREFIX ?= /opt/$(TARGET)/
BIONIC_LIBS = $(wildcard libs/*.so)

SOURCES += $(TARGET).c
SOURCES += $(LINKER_SOURCES)
SOURCES += $(COMPAT_SOURCES)
SOURCES += $(APKLIB_SOURCES)
SOURCES += $(JNIENV_SOURCES)
SOURCES += $(IMAGELIB_SOURCES)
SOURCES += $(DEBUG_SOURCES)
PLATFORM ?= sdl
ifeq ($(PLATFORM),pandora)
PANDORA = 1
else
PANDORA = 0
endif


#ifeq ($(PANDORA),1)
#SOURCES += platform/pandora.c
#else
#SOURCES += platform/maemo.c
#endif
SOURCES += platform/$(PLATFORM).c
OBJS = $(patsubst %.c,%.o,$(SOURCES))
MODULES = $(patsubst modules/%.c,%.apkenv.so,$(MODULES_SOURCES))

LDFLAGS = -fPIC -ldl -lz -pthread -lpng -ljpeg
ifeq ($(PLATFORM),sdl)
LDFLAGS += -lSDL
endif
ifeq ($(PANDORA),1)
CFLAGS += -DPANDORA -DNO_HARDFP -O2 -pipe
LDFLAGS += -lrt -lSDL -lSDL_mixer
endif
ifeq ($(SOFTFP),1)
CFLAGS += -DNO_HARDFP
endif
# Selection of OpenGL ES version support (if any) to include
CFLAGS += -DAPKENV_GLES
LDFLAGS += -lGLESv1_CM
CFLAGS += -DAPKENV_GLES2
LDFLAGS += -lGLESv2 -lEGL

FREMANTLE ?= 0
ifeq ($(FREMANTLE),1)
    CFLAGS += -DFREMANTLE -DNO_HARDFP
    LDFLAGS += -lSDL_gles -lSDL -lSDL_mixer
endif
GDB ?= 1
ifeq ($(GDB),1)
    CFLAGS += -g -Wall -Wformat=0
endif
DEBUG ?= 0
ifeq ($(DEBUG),1)
    CFLAGS += -DLINKER_DEBUG=1 -DAPKENV_DEBUG
else
    CFLAGS += -DLINKER_DEBUG=0
endif

all: $(TARGET) $(MODULES)

%.o: %.c
	@echo -e "\tCC\t$@"
	@$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET): $(OBJS)
	@echo -e "\tLINK\t$@"
	@$(CC) $(LDFLAGS) $(OBJS) -o $@

%.apkenv.so: modules/%.c
	@echo -e "\tMOD\t$@"
	@$(CC) -fPIC -shared $(CFLAGS) -lSDL -lSDL_mixer -o $@ $<

strip:
	@echo -e "\tSTRIP"
	@strip $(TARGET) $(MODULES)

install: $(TARGET) $(MODULES)
	@echo -e "\tMKDIR"
	@mkdir -p $(DESTDIR)$(PREFIX)/{modules,bionic}
	@mkdir -p $(DESTDIR)/usr/bin
	@echo -e "\tINSTALL\t$(TARGET)"
	@install -m755 $(TARGET) $(DESTDIR)/usr/bin
	@echo -e "\tINSTALL\tMODULES"
	@install -m644 $(MODULES) $(DESTDIR)$(PREFIX)/modules
ifneq ($(PANDORA),1)
	@echo -e "\tINSTALL\tBIONIC"
	@install -m644 $(BIONIC_LIBS) $(DESTDIR)$(PREFIX)/bionic
ifneq ($(FREMANTLE),1)
	@echo -e "\tINSTALL\tHarmattan Resource Policy"
	@install -d -m755 $(DESTDIR)/usr/share/policy/etc/syspart.conf.d
	@install -m644 $(TARGET).conf $(DESTDIR)/usr/share/policy/etc/syspart.conf.d
endif
else
	@echo -e "\tINSTALL\tlibs"
	@mkdir -p $(DESTDIR)$(PREFIX)/system/lib
	@install -m644 libs/pandora/system/lib/*.so $(DESTDIR)$(PREFIX)/system/lib/
endif

clean:
	@echo -e "\tCLEAN"
	@rm -rf $(TARGET) $(OBJS) $(MODULES)


.DEFAULT: all
.PHONY: strip install clean

