#
# Copyright (c) 2015 Andrew Ayer
# Copyright (c) 2026 Reinhold Fischer
# See COPYING file for license information.
#

CXXFLAGS ?= -Wall -pedantic -Wno-long-long -O2
CXXFLAGS += -std=c++11

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man

ENABLE_MAN ?= no
DOCBOOK_XSL ?= http://cdn.docbook.org/release/xsl-nons/current/manpages/docbook.xsl

# OS detection
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)

# -------------------------------------------------------------------
# OS-specific configuration
# -------------------------------------------------------------------

# Linux
ifeq ($(UNAME_S),Linux)
    OS_NAME := linux
    CXXFLAGS += -D_LARGEFILE64_SOURCE
    LDFLAGS += -lcrypto -ldl -lpthread
    ifdef STATIC
        LDFLAGS = -static -lcrypto -ldl -lpthread
        CXXFLAGS += -static -static-libgcc -static-libstdc++
    endif
endif

# macOS
ifeq ($(UNAME_S),Darwin)
    OS_NAME := darwin
    LDFLAGS += -lcrypto
    CXXFLAGS += -stdlib=libc++
    ifdef STATIC
        LDFLAGS += -static-libstdc++
    endif
endif

# Windows (MSYS2/MSYS_NT)
ifeq ($(findstring MSYS_NT,$(UNAME_S)),MSYS_NT)
    OS_NAME := windows
    CXXFLAGS += -D_WIN32_WINNT=0x0600
    CXXFLAGS += -static -static-libgcc -static-libstdc++

    # Static linking for Windows
    # IMPORTANT: OpenSSL libraries MUST come BEFORE Windows libraries!
    LDFLAGS = -static -static-libgcc -static-libstdc++
    LDFLAGS += -Wl,-Bstatic
    LDFLAGS += -lssl -lcrypto -lbcrypt
    LDFLAGS += -lws2_32 -lgdi32 -luser32 -ladvapi32 -lshell32
    LDFLAGS += -lwinmm -lcomdlg32 -lole32 -loleaut32
    LDFLAGS += -lcrypt32 -lz
    LDFLAGS += -Wl,--gc-sections -Wl,--strip-all

    # For dynamic linking (use: make DYNAMIC=1)
    ifdef DYNAMIC
        LDFLAGS = -lcrypto -lssl -lws2_32 -lgdi32 -luser32 -ladvapi32 -lshell32
        CXXFLAGS = -Wall -pedantic -Wno-long-long -O2 -std=c++11 -D_WIN32_WINNT=0x0600
    endif
endif

# Windows (Cygwin)
ifeq ($(findstring CYGWIN,$(UNAME_S)),CYGWIN)
    OS_NAME := cygwin
    LDFLAGS += -lcrypto -lws2_32 -lgdi32 -luser32
    ifdef STATIC
        LDFLAGS = -static -lcrypto -lws2_32 -lgdi32 -luser32
        LDFLAGS += -static-libgcc -static-libstdc++
        CXXFLAGS += -static -static-libgcc -static-libstdc++
    endif
endif

# Windows (MinGW)
ifeq ($(findstring MINGW,$(UNAME_S)),MINGW)
    OS_NAME := mingw
    CXXFLAGS += -D_WIN32_WINNT=0x0600
    LDFLAGS += -lcrypto -lws2_32 -lgdi32 -luser32 -ladvapi32 -lshell32
    ifdef STATIC
        LDFLAGS = -static -lcrypto -lws2_32 -lgdi32 -luser32 -ladvapi32 -lshell32
        LDFLAGS += -static-libgcc -static-libstdc++
        CXXFLAGS += -static -static-libgcc -static-libstdc++
    endif
endif

# Debug output
$(info Building for OS: $(OS_NAME))

# -------------------------------------------------------------------
# Build
# -------------------------------------------------------------------

OBJFILES = \
    git-crypt.o \
    commands.o \
    crypto.o \
    gpg.o \
    key.o \
    util.o \
    parse_options.o \
    coprocess.o \
    fhstream.o

OBJFILES += crypto-openssl-11.o

BUILD_MAN_TARGETS-yes = build-man
BUILD_MAN_TARGETS-no =
BUILD_TARGETS := build-bin $(BUILD_MAN_TARGETS-$(ENABLE_MAN))

all: build

build: $(BUILD_TARGETS)

build-bin: git-crypt

git-crypt: $(OBJFILES)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJFILES) $(LDFLAGS)

util.o: util.cpp util-unix.cpp util-win32.cpp
coprocess.o: coprocess.cpp coprocess-unix.cpp coprocess-win32.cpp

build-man: man/man1/git-crypt.1

man/man1/git-crypt.1: man/git-crypt.xml
	$(XSLTPROC) $(DOCBOOK_FLAGS) $(DOCBOOK_XSL) man/git-crypt.xml

# -------------------------------------------------------------------
# Clean
# -------------------------------------------------------------------

CLEAN_MAN_TARGETS-yes = clean-man
CLEAN_MAN_TARGETS-no =
CLEAN_TARGETS := clean-bin $(CLEAN_MAN_TARGETS-$(ENABLE_MAN))

clean: $(CLEAN_TARGETS)

clean-bin:
	rm -f $(OBJFILES) git-crypt

clean-man:
	rm -f man/man1/git-crypt.1

# -------------------------------------------------------------------
# Install
# -------------------------------------------------------------------

INSTALL_MAN_TARGETS-yes = install-man
INSTALL_MAN_TARGETS-no =
INSTALL_TARGETS := install-bin $(INSTALL_MAN_TARGETS-$(ENABLE_MAN))

install: $(INSTALL_TARGETS)

install-bin: build-bin
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 git-crypt $(DESTDIR)$(BINDIR)/

install-man: build-man
	install -d $(DESTDIR)$(MANDIR)/man1
	install -m 644 man/man1/git-crypt.1 $(DESTDIR)$(MANDIR)/man1/

# -------------------------------------------------------------------
# Phony targets
# -------------------------------------------------------------------

.PHONY: all \
	build build-bin build-man \
	clean clean-bin clean-man \
	install install-bin install-man
