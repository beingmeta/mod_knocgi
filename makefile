DEBUG_KNOCGI=
APXS=$(shell which apxs)
SUDO=$(shell which sudo)

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
	${SUDO} apxs -i -a mod_knocgi.la

update-apache: mod_knocgi
	make install && sudo apachectl restart

clean:
	rm -f mod_knocgi.la mod_knocgi.lo mod_knocgi.slo mod_knocgi.so mod_knocgi.o
