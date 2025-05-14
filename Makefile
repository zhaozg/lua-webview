PLAT   ?= linux
LIBNAME = webview


LUA ?= luajit
LUA_VERSION  = $(shell $(LUA) -e "print(string.sub(_VERSION, 5))")
LUA_CFLAGS  ?= $(shell pkg-config --cflags $(LUA))
LUA_LDFLAGS ?= $(shell pkg-config --libs $(LUA))
INST_LIBDIR ?= /usr/local/lib/lua/5.1

CFLAGS_darwin = -Wall -Wextra -pedantic
LIBFLAG_darwin = -framework WebKit
TARGET_darwin = $(LIBNAME).so

CFLAGS_windows = -Wall -Wextra -Wno-unused-parameter -Wstrict-prototypes
LIBFLAG_windows = -O -Wl,-s -static-libgcc -lole32 -lcomctl32 -loleaut32 -luuid -mwindows
TARGET_windows = $(LIBNAME).dll

CFLAGS_linux = -fPIC -pedantic  -Wall -Wextra -Wno-unused-parameter -Wstrict-prototypes \
	       -DWEBVIEW_GTK=1 $(shell pkg-config --cflags gtk+-3.0 webkit2gtk-4.0)
LIBFLAG_linux= -static-libgcc -Wl,-s $(shell pkg-config --libs gtk+-3.0 webkit2gtk-4.0)
TARGET_linux = $(LIBNAME).so

CFLAGS   += $(LUA_CFLAGS) $(CFLAGS_$(PLAT))
LIBFLAGS += $(LIBFLAG_$(PLAT)) $(LUA_LDFLAGS)

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
	@echo CFLAGS: $(CFLAGS)
	@echo LIBFLAG: $(LIBFLAG)
	@echo LUA: $(LUA)

show-install:
	@echo PREFIX: $(PREFIX) or $(INST_PREFIX)
	@echo BINDIR: $(BINDIR) or $(INST_BINDIR)
	@echo LIBDIR: $(LIBDIR) or $(INST_LIBDIR)
	@echo LUADIR: $(LUADIR) or $(INST_LUADIR)

$(TARGET): $(OBJS)
	$(CC) -shared $(OBJS) $(LIBFLAGS) -o $(TARGET)

clean:
	-$(RM) $(OBJS) $(TARGET)

$(OBJS): %.o : %.cc $(SOURCES)
	$(CC) $(CFLAGS) $(C1FLAGS_$(PLAT)) -c -o $@ $<
