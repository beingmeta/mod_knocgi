KNOCONFIG       ::= knoconfig
KNOBUILD          = knobuild

APXSCMD         ::= $(shell which apxs)
prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
LIBEXECDIR      ::= $(DESTDIR)$(shell ${APXSCMD} -q LIBEXECDIR)
SYSCONFDIR 	::= $(DESTDIR)$(shell ${APXSCMD} -q SYSCONFDIR)
APXCONF_D	::= $(DESTDIR)$(shell ${APXSCMD} -q SYSCONFDIR)/conf.d
CODENAME	::= $(shell ${KNOCONFIG} codename)
RELSTATUS	::= $(shell ${KNOCONFIG} status)
APXS		= ${APXSCMD} -S LIBEXECDIR=${LIBEXECDIR} -S SYSCONFDIR=${SYSCONFDIR}
SYSINSTALL	= /usr/bin/install -c
MOD_VERSION	= 1912
GPGID        	= FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO         	= $(shell which sudo)

DEFAULT_ARCH    ::= $(shell /bin/arch)
ARCH            ::= $(shell ${KNOBUILD} ARCH ${DEFAULT_ARCH})
APKREPO         ::= $(shell ${KNOBUILD} getbuildopt APKREPO /srv/repo/kno/apk)
APK_ARCH_DIR      = ${APKREPO}/staging/${ARCH}

DEBUG_KNOCGI 	=

mod_knocgi.so: mod_knocgi.c fileinfo makefile
	@echo "#define _FILEINFO \""$(shell ./fileinfo mod_knocgi.c)"\"" \
		> mod_knocgi_fileinfo.h
	${APXS} -DDEBUG_KNOCGI=$(DEBUG_KNOCGI) -c mod_knocgi.c -lu8

mod_knocgi: mod_knocgi.so

fileinfo: etc/fileinfo.c
	$(CC) -o fileinfo etc/fileinfo.c

${LIBEXECDIR} ${SYSCONFDIR} ${APXCONF_D}:
	@install -d $@

# For OSX, try this
# apxs -Wc,'-arch x86_64' -Wl,'-arch x86_64'  -a -i -c src/apache2/mod_knocgi.c
install: mod_knocgi.so ${LIBEXECDIR} ${SYSCONFDIR}
	${SUDO} ${APXS} -i -A mod_knocgi.la
	${SUDO} ${SYSINSTALL} knocgi.load ${DESTDIR}/etc/apache2/mods-available
	${SUDO} ${SYSINSTALL} knocgi.conf ${DESTDIR}/etc/apache2/mods-available
conf.d-install: mod_knocgi.so ${LIBEXECDIR} ${SYSCONFDIR} ${APXCONF_D}
	${SUDO} ${APXS} -i mod_knocgi.la
	${SUDO} ${SYSINSTALL} knocgi.conf ${APXCONF_D}

update-apache: mod_knocgi
	make install && sudo apachectl restart

clean:
	rm -f mod_knocgi.so mod_knocgi.o \
	      mod_knocgi.la mod_knocgi.lo mod_knocgi.slo 

debian: mod_knocgi.c makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian

debian/changelog: debian mod_knocgi.c makefile
	cat debian/changelog.base | \
		knomod debchangelog libapache2-mod-knocgi ${CODENAME} ${RELSTATUS} > $@.tmp
	if test ! -f debian/changelog; then \
	  mv debian/changelog.tmp debian/changelog; \
	elif diff debian/changelog debian/changelog.tmp 2>&1 > /dev/null; then \
	  mv debian/changelog.tmp debian/changelog; \
	else rm debian/changelog.tmp; fi

dist/debian.built: mod_knocgi.c makefile debian debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

dist/debian.signed: dist/debian.built
	debsign --re-sign -k${GPGID} ../libapache2-mod-knocgi_*.changes && \
	touch $@

deb debs dpkg dpkgs: dist/debian.signed

debinstall: dist/debian.signed
	sudo dpkg -i ../libapache2-mod-knocgi_${MOD_VERSION}*.deb

dist/debian.updated: dist/debian.signed
	dupload -c ./debian/dupload.conf --nomail --to bionic ../libapache2-mod-knocgi_*.changes && \
	touch $@

update-apt: dist/debian.updated

debclean: clean
	rm -rf ../libapache2-mod_knocgi* debian dist/debian.*

debfresh:
	make debclean
	make dist/debian.signed

# Alpine packaging

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/mod-knocgi.tar: staging/alpine
	git archive --prefix=mod-knocgi/ -o staging/alpine/mod-knocgi.tar HEAD

dist/alpine.done: staging/alpine/APKBUILD makefile staging/alpine/mod-knocgi.tar
	if [ ! -d ${APK_ARCH_DIR} ]; then mkdir -p ${APK_ARCH_DIR}; fi;
	cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum && \
		abuild -P ${APKREPO} && \
		touch ../../$@

alpine: dist/alpine.done

.PHONY: alpine

