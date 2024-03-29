KNOCONFIG       ::= knoconfig
KNOBUILD          = knobuild

APXSCMD         ::= $(shell which apxs2 2>/dev/null||which apxs2 2>/dev/null||echo apxs2)
prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
WEBUSER 	::= $(shell ${KNOCONFIG} webuser)
LIBEXECDIR      ::= $(DESTDIR)$(shell ${APXSCMD} -q LIBEXECDIR)
SYSCONFDIR 	::= $(DESTDIR)$(shell ${APXSCMD} -q SYSCONFDIR)
APXCONF_D	::= $(DESTDIR)$(shell ${APXSCMD} -q SYSCONFDIR)/conf.d
CODENAME	::= $(shell ${KNOCONFIG} codename)
REL_BRANCH	::= $(shell ${KNOBUILD} getbuildopt REL_BRANCH current)
REL_STATUS	::= $(shell ${KNOBUILD} getbuildopt REL_STATUS stable)
REL_PRIORITY	::= $(shell ${KNOBUILD} getbuildopt REL_PRIORITY medium)
CFLAGS		= -O2 -g -Wno-pointer-sign
APXS		= ${APXSCMD} -S CFLAGS="${CFLAGS}" -S LIBEXECDIR=${LIBEXECDIR} -S SYSCONFDIR=${SYSCONFDIR}
SYSINSTALL	= /usr/bin/install -c
GPGID        	= FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO         	= $(shell which sudo)
DEBUG_KNOCGI 	=

KNOCGI_VERSION	::= $(shell cat ./version)
PATCH_VERSION	::= $(shell u8_gitversion ./version)


BINDIR		::= $(shell ${KNOCONFIG} bin)
RUNDIR		::= $(shell ${KNOCONFIG} rundir)
LOGDIR		::= $(shell ${KNOCONFIG} logdir)

DEFAULT_ARCH    ::= $(shell uname -m)
ARCH            ::= $(shell ${KNOBUILD} getbuildopt BUILD_ARCH || uname -m)
APKREPO         ::= $(shell ${KNOBUILD} getbuildopt APKREPO /srv/repo/kno/apk)
APK_ARCH_DIR      = ${APKREPO}/staging/${ARCH}

default: mod_knocgi.so knocgi.conf knocgi.load
debug: clean
	make DEBUG_KNOCGI=1 mod_knocgi.so knocgi.conf knocgi.load

mod_knocgi.so: mod_knocgi.c makefile
	@echo "#define _FILEINFO \""$(shell u8_fileinfo mod_knocgi.c)"\"" \
		> mod_knocgi_fileinfo.h
	if test ! -z "${DEBUG_KNOCGI}"; then 				\
	   ${APXS} -DDEBUG_KNOCGI=$(DEBUG_KNOCGI) -c mod_knocgi.c -lu8; \
	else ${APXS} -c mod_knocgi.c -lu8; fi;

mod_knocgi: mod_knocgi.so

${LIBEXECDIR} ${SYSCONFDIR} ${APXCONF_D}:
	@install -d $@

knocgi.conf: knocgi.conf.in
	cp knocgi.conf.in knocgi.conf
	$(KNOBUILD) dosubst knocgi.conf \
		@WEBUSER@ ${WEBUSER} \
		@LIBEXECDIR@ ${LIBEXECDIR} \
		@BINDIR@ ${BINDIR} @RUNDIR@ ${RUNDIR} @LOGDIR@ ${LOGDIR}

knocgi.load: knocgi.load.in
	cp knocgi.load.in knocgi.load
	${KNOBUILD} dosubst knocgi.load LIBEXECDIR ${LIBEXECDIR}

# For OSX, try this
# apxs -Wc,'-arch x86_64' -Wl,'-arch x86_64'  -a -i -c src/apache2/mod_knocgi.c
install: mod_knocgi.so knocgi.conf knocgi.load ${LIBEXECDIR} ${SYSCONFDIR}
	${SUDO} ${APXS} -i -A mod_knocgi.la
	${SUDO} ${SYSINSTALL} knocgi.load ${DESTDIR}/etc/apache2/mods-available
	${SUDO} ${SYSINSTALL} knocgi.conf ${DESTDIR}/etc/apache2/mods-available
conf.d-install: mod_knocgi.so knocgi.conf ${LIBEXECDIR} ${SYSCONFDIR} ${APXCONF_D}
	${SUDO} ${APXS} -i mod_knocgi.la
	${SUDO} ${SYSINSTALL} knocgi.conf ${APXCONF_D}

update-apache: mod_knocgi
	make install && sudo apachectl restart

clean:
	rm -f mod_knocgi.so mod_knocgi.o \
	      mod_knocgi.la mod_knocgi.lo mod_knocgi.slo 
fresh:
	make clean
	make default

gitup gitup-trunk:
	git checkout trunk && git pull

# Alpine packaging

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/mod-knocgi.tar: staging/alpine
	git archive --prefix=mod-knocgi/ -o staging/alpine/mod-knocgi.tar HEAD

dist/alpine.setup: staging/alpine/APKBUILD makefile ${STATICLIBS} \
	staging/alpine/mod-knocgi.tar
	if [ ! -d ${APK_ARCH_DIR} ]; then mkdir -p ${APK_ARCH_DIR}; fi && \
	( cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum ) && \
	touch $@

dist/alpine.done: dist/alpine.setup
	( cd staging/alpine; abuild -P ${APKREPO} ) && touch $@
dist/alpine.installed: dist/alpine.setup
	( cd staging/alpine; abuild -i -P ${APKREPO} ) && touch dist/alpine.done && touch $@


alpine: dist/alpine.done
install-alpine: dist/alpine.done

.PHONY: alpine

