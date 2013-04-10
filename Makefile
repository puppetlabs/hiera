#!/usr/bin/make -f

NAME=hiera
RUBY=ruby
SYSCONFDIR=$(DESTDIR)/etc
LIBDIR=$(shell $(RUBY) -rrbconfig -e 'puts RbConfig::CONFIG["sitelibdir"]')
RUBYBINDIR=$(shell $(RUBY) -rrbconfig -e 'puts RbConfig::CONFIG["bindir"]')
DOCDIR=$(DESTDIR)/usr/share/doc/$(NAME)

all:

install::
	mkdir -p $(LIBDIR)
	mkdir -p $(RUBYBINDIR)
	mkdir -p $(DOCDIR)
	mkdir -p $(SYSCONFDIR)
	cp -pr lib/hiera $(LIBDIR)
	cp -p lib/hiera.rb $(LIBDIR)
	cp -p bin/* $(RUBYBINDIR)
	cp -pr ext/hiera.yaml $(SYSCONFDIR)
	cp -p COPYING README.md $(DOCDIR)

clean::
