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

LUA  ?= luajit
PLAT ?= windows
LIBNAME = webview

ifdef LUA_LIBDIR
LUA_LIBDIR_OPT=-L$(LUA_LIBDIR)
else
LUA_LIBDIR_OPT=-L/usr/local/lib -lluajit-5.1
endif

LUA_INCDIR = /usr/local/include/luajit-2.1
ifeq ($(PLAT),windows)
LUA_LIBDIR_OPT+=$(LUA_LIBDIR)/luajit.lib
LUA_LIBNAME=luajit
else
LUA_LIBDIR_OPT+=-lluajit-5.1
#LUA_APP = $(LUA_BINDIR)/$(LUA)
LUA_APP = $(LUA)
LUA_VERSION = $(shell $(LUA_APP) -e "print(string.sub(_VERSION, 5))")
LUA_LIBNAME = lua$(subst .,,$(LUA_VERSION))
WEBVIEW_ARCH = x64
endif

ifeq ($(PLAT), windows)
ifneq ($(LUA), luajit)
LUA_BITS = $(shell $(LUA_APP) -e "print(string.len(string.pack('T', 0)) * 8)")
endif

ifeq ($(LUA_BITS),32)
  WEBVIEW_ARCH = x86
endif
endif

WEBVIEW_C = webview-c
MS_WEBVIEW2 = $(WEBVIEW_C)/ms.webview2

CFLAGS_windows = -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -Wstrict-prototypes \
  -I$(WEBVIEW_C) \
  -I$(MS_WEBVIEW2)/include \
  -I$(LUA_INCDIR) \
  -DWEBVIEW_WINAPI=1

LIBFLAG_windows = -O \
  -shared \
  -Wl,-s \
  -static-libgcc \
  -lole32 -lcomctl32 -loleaut32 -luuid -lgdi32 \
  $(LUA_LIBDIR_OPT) -l$(LUA_LIBNAME) \

TARGET_windows = $(LIBNAME).dll

CFLAGS_linux = -pedantic  \
  -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -Wstrict-prototypes \
  -I$(WEBVIEW_C) \
  -I$(LUA_INCDIR) \
  -DWEBVIEW_GTK=1 \
  $(shell pkg-config --cflags gtk+-3.0 webkit2gtk-4.0)

LIBFLAG_linux= -static-libgcc \
  -Wl,-s \
  $(LUA_LIBDIR_OPT) \
  $(shell pkg-config --libs gtk+-3.0 webkit2gtk-4.0)

TARGET_linux = $(LIBNAME).so

CFLAGS_darwin = -pedantic  \
  -Wall \
  -Wextra \
  -Wno-unused-parameter \
  -Wstrict-prototypes \
  -ObjC -DOBJC_OLD_DISPATCH_PROTOTYPES=1 \
  -I$(WEBVIEW_C) \
  -I$(LUA_INCDIR) \
  -DWEBVIEW_COCOA=1

LIBFLAG_darwin = -shared -undefined dynamic_lookup \
		 -framework WebKit $(LUA_LIBDIR_OPT)
TARGET_darwin = $(LIBNAME).so

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
	@echo LUA_LIBNAME: $(LUA_LIBNAME)
	@echo CFLAGS: $(CFLAGS)
	@echo LIBFLAG: $(LIBFLAG)
	@echo LUA_LIBDIR: $(LUA_LIBDIR)
	@echo LUA_BINDIR: $(LUA_BINDIR)
	@echo LUA_INCDIR: $(LUA_INCDIR)
	@echo LUA: $(LUA)
	@echo LUALIB: $(LUALIB)

show-install:
	@echo PREFIX: $(PREFIX) or $(INST_PREFIX)
	@echo BINDIR: $(BINDIR) or $(INST_BINDIR)
	@echo LIBDIR: $(LIBDIR) or $(INST_LIBDIR)
	@echo LUADIR: $(LUADIR) or $(INST_LUADIR)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) $(LIBFLAG) $(LIBFLAG_$(PLAT)) -o $(TARGET)

clean:
	-$(RM) $(OBJS) $(TARGET_linux) $(TARGET_darwin) $(TARGET_windows)

$(OBJS): %.o : %.c $(SOURCES)
	$(CC) $(CFLAGS) $(CFLAGS_$(PLAT)) -c -o $@ $<
