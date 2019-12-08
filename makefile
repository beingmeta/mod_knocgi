DEBUG_KNOCGI=
APXSCMD=$(shell which apxs)
APXS=${APXSCMD} -S LIBEXECDIR=$(DESTDIR)/usr/lib/apache2/modules -S SYSCONFDIR=${DESTDIR}/etc/apache2
SYSINSTALL=/usr/bin/install -c
GPGID=FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO=

mod_knocgi.so: mod_knocgi.c fileinfo makefile
	@echo "#define _FILEINFO \""$(shell ./fileinfo mod_knocgi.c)"\"" \
		> mod_knocgi_fileinfo.h
	${APXS} -DDEBUG_KNOCGI=$(DEBUG_KNOCGI) -c mod_knocgi.c -lu8

mod_knocgi: mod_knocgi.so

fileinfo: etc/fileinfo.c
	$(CC) -o fileinfo etc/fileinfo.c

# For OSX, try this
# apxs -Wc,'-arch x86_64' -Wl,'-arch x86_64'  -a -i -c src/apache2/mod_knocgi.c
install: mod_knocgi.so
	${SUDO} ${APXS} -i -a mod_knocgi.la
	${SYSINSTALL} knocgi.load ${DESTDIR}/etc/apache2/mods-available
	${SYSINSTALL} knocgi.conf ${DESTDIR}/etc/apache2/mods-available


update-apache: mod_knocgi
	make install && sudo apachectl restart

clean:
	rm -f mod_knocgi.so mod_knocgi.o \
	      mod_knocgi.la mod_knocgi.lo mod_knocgi.slo 

debian.built: mod_knocgi.c makefile debian/rules debian/control
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	debsign --re-sign -k${GPGID} ../libapache2-mod-knocgi_1912*.changes && \
	touch $@

debian.pushed: debian.built
	dupload -c ./debian/dupload.conf --nomail --to bionic ../libapache2-mod-knocgi_*.changes && touch $@

debclean:
	rm ../libpache2-mod-knocgi*

debfresh:
	make debclean
	make debian.built
