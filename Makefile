#
# Makefile for rockspec
#
# Install with Lua Binaries:
#  luarocks --lua-dir C:/bin/lua-5.3.5_Win64_bin MAKE=make CC=gcc LD=gcc install lua-webview
#
# Build with luaclibs:
#  luarocks --lua-dir ../../luaclibs/lua/src MAKE=make CC=gcc LD=gcc make
#  luarocks --lua-dir C:/bin/lua-5.4.2_Win64_bin MAKE=make CC=gcc LD=gcc make lua-webview-1.3-2.rockspec
#

CC ?= gcc

PLAT ?= $(shell echo $(shell uname) | tr '[:upper:]' '[:lower:]')
LIBNAME = webview

LUA ?= luajit
LUA_APP = $(LUA)
LUA_VERSION = $(shell $(LUA_APP) -e "print(string.sub(_VERSION, 5))")
LUA_BITS ?= 64
LUA_CFLAGS = $(shell pkg-config --cflags $(LUA))
LUA_LDFLAGS = $(shell pkg-config --libs $(LUA))

WEBVIEW_ARCH = x64
ifeq ($(LUA_BITS),32)
  WEBVIEW_ARCH = x86
endif

WEBVIEW_C = webview-c
MS_WEBVIEW2 = $(WEBVIEW_C)/ms.webview2

CFLAGS_windows = -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -Wstrict-prototypes \
  -I$(WEBVIEW_C) \
  -I$(MS_WEBVIEW2)/include \
  -DWEBVIEW_WINAPI=1

LIBFLAG_windows = -O \
  -Wl,-s \
  $(LUA_LIBDIR_OPT) -l$(LUA_LIBNAME) \
  -static-libgcc \
  -lole32 -lcomctl32 -loleaut32 -luuid -lgdi32

TARGET_windows = $(LIBNAME).dll

CFLAGS_linux = -pedantic  \
	-fPIC \
  -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -Wstrict-prototypes \
  -I$(WEBVIEW_C) \
  -DWEBVIEW_GTK=1 \
  $(shell pkg-config --cflags gtk+-3.0 webkit2gtk-4.0)

LIBFLAG_linux= -static-libgcc \
  -Wl,-s \
  $(shell pkg-config --libs gtk+-3.0 webkit2gtk-4.0)

TARGET_linux = $(LIBNAME).so


TARGET = $(TARGET_$(PLAT))

SOURCES = webview.c

OBJS = webview.o

lib: $(TARGET)

install: install-$(PLAT)
	cp $(TARGET) $(INST_LIBDIR)
	-cp webview-launcher.lua $(INST_LUADIR)

install-linux:

install-windows:
	cp $(MS_WEBVIEW2)/$(WEBVIEW_ARCH)/WebView2Loader.dll $(INST_BINDIR)

show:
	@echo PLAT: $(PLAT)
	@echo LUA_VERSION: $(LUA_VERSION)
	@echo LUA_CFLAGS: $(LUA_CFLAGS)
	@echo LUA_LDFLAGS: $(LUA_LDFLAGS)
	@echo CFLAGS: $(CFLAGS)
	@echo LIBFLAG: $(LIBFLAG)
	@echo LUA: $(LUA)
	@echo LUALIB: $(LUALIB)

show-install:
	@echo PREFIX: $(PREFIX) or $(INST_PREFIX)
	@echo BINDIR: $(BINDIR) or $(INST_BINDIR)
	@echo LIBDIR: $(LIBDIR) or $(INST_LIBDIR)
	@echo LUADIR: $(LUADIR) or $(INST_LUADIR)

$(TARGET): $(OBJS)
	$(CC) -shared $(OBJS) $(LIBFLAG) $(LUA_LDFALGS) $(LIBFLAG_$(PLAT)) -o $(TARGET)

clean:
	-$(RM) $(OBJS) $(TARGET)

$(OBJS): %.o : %.c $(SOURCES)
	$(CC) $(CFLAGS) $(LUA_CFLAGS) $(CFLAGS_$(PLAT)) -c -o $@ $<
