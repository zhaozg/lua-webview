PLAT ?= darwin
LIBNAME = webview


LUA ?= /usr/local/bin/luajit
LUA_VERSION = $(shell $(LUA) -e "print(string.sub(_VERSION, 5))")
LUA_LIBNAME = lua$(subst .,,$(LUA_VERSION))
LUA_INCDIR ?= /usr/local/include/luajit-2.1
LUA_LIBDIR ?= /usr/local/lib

CFLAGS_darwin = -Wall -Wextra -Wno-unused-parameter -Wstrict-prototypes \
		 -DWEBVIEW_COCOA=1 -I$(LUA_INCDIR)
LIBFLAG_darwin = -shared -framework Cocoa -framework WebKit -L$(LUA_LIBDIR) -lluajit-5.1
TARGET_darwin = $(LIBNAME).so


CFLAGS_windows = -Wall -Wextra -Wno-unused-parameter -Wstrict-prototypes \
		 -I$(LUA_INCDIR) -DWEBVIEW_WINAPI=1
LIBFLAG_windows = -O -shared -Wl,-s -L$(LUA_LIBDIR) -l$(LUA_LIBNAME) -static-libgcc \
		  -lole32 -lcomctl32 -loleaut32 -luuid -mwindows
TARGET_windows = $(LIBNAME).dll

CFLAGS_linux = -pedantic  -Wall -Wextra -Wno-unused-parameter -Wstrict-prototypes -I$(LUA_INCDIR) \
	       -DWEBVIEW_GTK=1 $(shell pkg-config --cflags gtk+-3.0 webkit2gtk-4.0)
LIBFLAG_linux= -static-libgcc -Wl,-s  -L$(LUA_LIBDIR) $(shell pkg-config --libs gtk+-3.0 webkit2gtk-4.0)
TARGET_linux = $(LIBNAME).so


CFLAGS+= $(CFLAGS_$(PLAT))

TARGET = $(TARGET_$(PLAT))

SOURCES = webview.cc

OBJS = webview.o

CC = c++ -std=c++11

lib: $(TARGET)

install:
	cp $(TARGET) $(INST_LIBDIR)

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
	-$(RM) $(OBJS) $(TARGET)

$(OBJS): %.o : %.cc $(SOURCES)
	$(CC) $(CFLAGS) $(C1FLAGS_$(PLAT)) -c -o $@ $<
