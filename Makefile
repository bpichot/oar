#!/usr/bin/make
# $Id$
SHELL=/bin/bash

OARCONFDIR=/etc/oar
# OARUSER and OAROWNER should be the same value except for special needs 
# (Debian packaging) 
OARUSER=oar
# OAROWNER is the variable expanded to set the ownership of the files
OAROWNER=$(OARUSER)
OAROWNERGROUP=$(OAROWNER)

# Set the user of web server (for CGI installation)
WWWUSER=www-data

PREFIX=/usr/local
MANDIR=$(PREFIX)/man
OARDIR=$(PREFIX)/oar
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
DOCDIR=$(PREFIX)/doc/oar
WWWDIR=/var/www
CGIDIR=/usr/lib/cgi-bin
WWW_ROOTDIR=
GANTT_WEB_ROOT=$(WWWDIR)
GANTT_WEB_DIR=drawgantt
XAUTHCMDPATH=$(shell which xauth)
ifeq "$(XAUTHCMDPATH)" ""
	XAUTHCMDPATH=/usr/bin/xauth
endif

.PHONY: man

all: usage
install: usage
usage:
	@echo "Usage: make [ OPTIONS=<...> ] MODULES"
	@echo "Where MODULES := { server-install | user-install | node-install | monika-install | draw-gantt-install | doc-install | desktop-computing-agent-install | desktop-computing-cgi-install | tools-install | api-install | gridapi-install}"
	@echo "      OPTIONS := { OARCONFDIR | OARUSER | OAROWNER | PREFIX | MANDIR | OARDIR | BINDIR | SBINDIR | DOCDIR }"

sanity-check:
	@[ "`id root`" = "`id`" ] || echo "Warning: root-privileges are required to install some files !"
	@id $(OAROWNER) > /dev/null || ( echo "Error: User $(OAROWNER) does not exist!" ; exit -1 )

man:
	@cd man/man1/ && for i in `ls *.pod | sed -ne 's/.pod//p'`; do pod2man --section=1 --release=$$1 --center "OAR commands" --name $$i "$$i.pod" > $$i.1 ; done

configuration:
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oar.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oar.conf already exists, not overwriting it." ; else install -m 0600 Tools/oar.conf $(DESTDIR)$(OARCONFDIR) ; chown $(OAROWNER).root $(DESTDIR)$(OARCONFDIR)/oar.conf || /bin/true ; fi

desktop-computing-agent:
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -m 0755 DesktopComputing/oar-agent.pl $(DESTDIR)$(BINDIR)/oar-agent

desktop-computing-cgi:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -m 0755 DesktopComputing/oarcache.pl $(DESTDIR)$(OARDIR)/oarcache.pl
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oarcache
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oarcache
	chmod 6750 $(DESTDIR)$(SBINDIR)/oarcache
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarcache.pl'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oarcache
	install -m 0755 DesktopComputing/oarres.pl $(DESTDIR)$(OARDIR)/oarres.pl
	install -m 6750 Tools/oardo $(DESTDIR)$(OARDIR)/oarres
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oarres
	chmod 6755 $(DESTDIR)$(OARDIR)/oarres
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarres.pl'\;#;;\
				" $(DESTDIR)$(OARDIR)/oarres
	install -m 0755 DesktopComputing/oar-cgi.pl $(DESTDIR)$(OARDIR)/oar-cgi.pl
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(CGIDIR)/oar-cgi
	-chown $(OAROWNER).$(WWWUSER) $(DESTDIR)$(CGIDIR)/oar-cgi
	chmod 6750 $(DESTDIR)$(CGIDIR)/oar-cgi
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oar-cgi.pl'\;#;;\
				" $(DESTDIR)$(CGIDIR)/oar-cgi

api:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0755 API/oarapi.pl $(DESTDIR)$(OARDIR)/oarapi.pl
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	mkdir -p $(DESTDIR)$(CGIDIR)/oarapi
	-chown $(OAROWNER).$(WWWUSER) $(DESTDIR)$(CGIDIR)/oarapi
	-chmod 750 $(DESTDIR)$(CGIDIR)/oarapi
	install -m 6755 Tools/oardo $(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	-chmod 6755 $(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarapi.pl'\;#;;\
				" $(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi
	install -m 6750 $(DESTDIR)$(CGIDIR)/oarapi/oarapi.cgi $(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi
	-chmod 6755 $(DESTDIR)$(CGIDIR)/oarapi/oarapi-debug.cgi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache-api.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache-api.conf already exists, not overwriting it." ; else install -m 0600 API/apache2.conf $(DESTDIR)$(OARCONFDIR)/apache-api.conf ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache-api.conf || /bin/true ; fi
	install -d -m 0755 $(DESTDIR)$(DOCDIR)
	install -m 0644 API/oarapi_examples.txt $(DESTDIR)$(DOCDIR)
	install -m 0644 API/INSTALL $(DESTDIR)$(DOCDIR)/API_INSTALL
	install -m 0644 API/TODO $(DESTDIR)$(DOCDIR)/API_TODO
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_header.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_header.pl already exists, not overwriting it." ; else install -m 0600 API/api_html_header.pl $(DESTDIR)$(OARCONFDIR)/api_html_header.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_header.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl already exists, not overwriting it." ; else install -m 0644 API/api_html_postform.pl $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/api_html_postform.pl || /bin/true ; fi

gridapi:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0755 API/oargridapi.pl $(DESTDIR)$(OARDIR)/oargridapi.pl
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	mkdir -p $(DESTDIR)$(CGIDIR)/oarapi
	-chown $(OAROWNER).$(WWWUSER) $(DESTDIR)$(CGIDIR)/oarapi
	-chmod 750 $(DESTDIR)$(CGIDIR)/oarapi
	install -m 6755 Tools/oardo $(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi
	-chmod 6755 $(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oargridapi.pl'\;#;;\
				" $(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi
	install -m 6750 $(DESTDIR)$(CGIDIR)/oarapi/oargridapi.cgi $(DESTDIR)$(CGIDIR)/oarapi/oargridapi-debug.cgi
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(CGIDIR)/oarapi/oargridapi-debug.cgi
	-chmod 6755 $(DESTDIR)$(CGIDIR)/oarapi/oargridapi-debug.cgi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf already exists, not overwriting it." ; else install -m 0600 API/apache2-grid.conf $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache-gridapi.conf || /bin/true ; fi
	install -d -m 0755 $(DESTDIR)$(DOCDIR)
	install -m 0644 API/oargridapi_examples.txt $(DESTDIR)$(DOCDIR)
	install -m 0644 API/oargridapi.txt $(DESTDIR)$(DOCDIR)
	install -m 0644 API/INSTALL $(DESTDIR)$(DOCDIR)/API_INSTALL
	install -m 0644 API/TODO $(DESTDIR)$(DOCDIR)/API_TODO
	@if [ -f $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl already exists, not overwriting it." ; else install -m 0600 API/gridapi_html_header.pl $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/gridapi_html_header.pl || /bin/true ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl already exists, not overwriting it." ; else install -m 0644 API/gridapi_html_postform.pl $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl ; chown $(OAROWNER) $(DESTDIR)$(OARCONFDIR)/gridapi_html_postform.pl || /bin/true ; fi

dbinit:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -m 0755 DB/oar_mysql_db_init.pl $(DESTDIR)$(OARDIR)/oar_mysql_db_init
	#ln -fs $(OARDIR)/oar_mysql_db_init $(SBINDIR)/oar_mysql_db_init
	install -m 0755 DB/oar_psql_db_init.pl $(DESTDIR)$(OARDIR)/oar_psql_db_init
	#ln -fs $(OARDIR)/oar_psql_db_init $(SBINDIR)/oar_psql_db_init
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	chmod 6750 $(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oar_mysql_db_init'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oar_mysql_db_init
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oar_psql_db_init
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oar_psql_db_init
	chmod 6750 $(DESTDIR)$(SBINDIR)/oar_psql_db_init
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oar_psql_db_init'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oar_psql_db_init
	install -m 0644 DB/default_data.sql $(DESTDIR)$(OARDIR)
	install -m 0644 DB/mysql_default_admission_rules.sql $(DESTDIR)$(OARDIR)
	install -m 0644 DB/mysql_structure.sql $(DESTDIR)$(OARDIR)
	install -m 0644 DB/pg_default_admission_rules.sql $(DESTDIR)$(OARDIR)
	install -m 0644 DB/pg_structure.sql $(DESTDIR)$(OARDIR)

common: man
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -m 0755 Tools/oarsh/oarsh $(DESTDIR)$(OARDIR)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#" $(OARDIR)/oarsh
	install -d -m 0755 $(DESTDIR)$(OARDIR)/oardodo
	install -m 0755 Tools/oarsh/oarsh_shell $(DESTDIR)$(OARDIR)
	perl -i -pe "s#^XAUTH_LOCATION=.*#XAUTH_LOCATION=$(XAUTHCMDPATH)#;;\
				 s#^OARDIR=.*#OARDIR=$(OARDIR)#;;\
				" $(DESTDIR)$(OARDIR)/oarsh_shell
	install -m 6750 Tools/oardodo $(DESTDIR)$(OARDIR)/oardodo
	-chown root.$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oardodo
	-chown root.$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oardodo/oardodo
	chmod 6750 $(DESTDIR)$(OARDIR)/oardodo
	chmod 6750 $(DESTDIR)$(OARDIR)/oardodo/oardodo
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oaruser = .*#Oaruser = '$(OARUSER)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				" $(DESTDIR)$(OARDIR)/oardodo/oardodo
	install -m 6755 Tools/oardo $(DESTDIR)$(OARDIR)/oarsh_oardo
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(OARDIR)/oarsh_oardo
	chmod 6755 $(DESTDIR)$(OARDIR)/oarsh_oardo
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarsh'\;#;;\
				" $(DESTDIR)$(OARDIR)/oarsh_oardo
	install -m 0755 Tools/oarsh/oarsh_sudowrapper.sh $(DESTDIR)$(BINDIR)/oarsh
	perl -i -pe "s#^OARDIR=.*#OARDIR=$(OARDIR)#;;\
				 s#^OARSHCMD=.*#OARSHCMD=oarsh_oardo#\
				" $(DESTDIR)$(BINDIR)/oarsh
	install -m 0755 Tools/oarsh/oarcp $(DESTDIR)$(BINDIR)
	perl -i -pe "s#^OARSHCMD=.*#OARSHCMD=$(BINDIR)/oarsh#" $(DESTDIR)$(BINDIR)/oarcp
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarsh.1 $(DESTDIR)$(MANDIR)/man1/oarcp.1
	install -m 0644 man/man1/oarsh.1 $(DESTDIR)$(MANDIR)/man1/oarsh.1
	install -m 0644 man/man1/oarprint.1 $(DESTDIR)$(MANDIR)/man1/oarprint.1
	install -m 0755 Qfunctions/oarprint $(DESTDIR)$(BINDIR)
	
libs: man
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -m 0644 ConfLib/oar_conflib.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Iolib/oar_iolib.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Judas/oar_Judas.pm $(DESTDIR)$(OARDIR)
	install -m 0755 Qfunctions/oarnodesetting $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oarnodesetting
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oarnodesetting
	chmod 6750 $(DESTDIR)$(SBINDIR)/oarnodesetting
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarnodesetting'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oarnodesetting
	install -m 0644 Scheduler/data_structures/oar_resource_tree.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Tools/oarversion.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Tools/oar_Tools.pm $(DESTDIR)$(OARDIR)
	install -m 0755 Tools/sentinelle.pl $(DESTDIR)$(OARDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh already exists, not overwriting it." ; else install -m 0644 Tools/oarnodesetting_ssh $(DESTDIR)$(OARCONFDIR); fi
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(SBINDIR)/oarnodesetting#" $(DESTDIR)$(OARCONFDIR)/oarnodesetting_ssh
	@if [ -f $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh already exists, not overwriting it." ; else install -m 0644 Tools/update_cpuset_id.sh $(DESTDIR)$(OARCONFDIR); fi
	perl -i -pe "s#^OARNODESETTINGCMD=.*#OARNODESETTINGCMD=$(SBINDIR)/oarnodesetting#" $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh
	perl -i -pe "s#^OARNODESCMD=.*#OARNODESCMD=$(BINDIR)/oarnodes#" $(DESTDIR)$(OARCONFDIR)/update_cpuset_id.sh
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarnodesetting.1 $(DESTDIR)$(MANDIR)/man1/oarnodesetting.1
	install -m 0644 API/oar_apilib.pm $(DESTDIR)$(OARDIR)


server: man
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(OARDIR)/schedulers
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -m 0755 Almighty/Almighty $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/Almighty
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/Almighty
	chmod 6750 $(DESTDIR)$(SBINDIR)/Almighty
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/Almighty'\;#;;\
				" $(DESTDIR)$(SBINDIR)/Almighty
	install -m 0755 Leon/Leon	$(DESTDIR)$(OARDIR)
	install -m 0755 Runner/runner $(DESTDIR)$(OARDIR)
	install -m 0755 Sarko/sarko $(DESTDIR)$(OARDIR)
	install -m 0755 Sarko/finaud $(DESTDIR)$(OARDIR)
	install -m 0644 Scheduler/data_structures/Gantt_hole_storage.pm $(DESTDIR)$(OARDIR)
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing $(DESTDIR)$(OARDIR)/schedulers/oar_sched_gantt_with_timesharing
	install -m 0755 Scheduler/oar_sched_gantt_with_timesharing_and_fairsharing $(DESTDIR)$(OARDIR)/schedulers/oar_sched_gantt_with_timesharing_and_fairsharing
	install -m 0755 Scheduler/oar_meta_sched $(DESTDIR)$(OARDIR)
	install -m 0644 Scheduler/oar_scheduler.pm $(DESTDIR)$(OARDIR)
	install -m 0755 Qfunctions/oarnotify $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oarnotify
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oarnotify
	chmod 6750 $(DESTDIR)$(SBINDIR)/oarnotify
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarnotify'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oarnotify
	install -m 0755 NodeChangeState/NodeChangeState $(DESTDIR)$(OARDIR)
	install -m 0755 Qfunctions/oarremoveresource $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oarremoveresource
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oarremoveresource
	chmod 6750 $(DESTDIR)$(SBINDIR)/oarremoveresource
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarremoveresource'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oarremoveresource
	install -m 0755 Qfunctions/oaraccounting $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oaraccounting
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oaraccounting
	chmod 6750 $(DESTDIR)$(SBINDIR)/oaraccounting
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oaraccounting'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oaraccounting
	install -m 0755 Qfunctions/oarproperty $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oarproperty
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oarproperty
	chmod 6750 $(DESTDIR)$(SBINDIR)/oarproperty
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarproperty'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oarproperty
	install -m 0755 Qfunctions/oarmonitor $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oarmonitor
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oarmonitor
	chmod 6750 $(DESTDIR)$(SBINDIR)/oarmonitor
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarmonitor'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oarmonitor
	install -m 0755 Runner/bipbip $(DESTDIR)$(OARDIR)
	install -m 0644 Runner/ping_checker.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Runner/oarexec $(DESTDIR)$(OARDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/job_resource_manager.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/job_resource_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/job_resource_manager.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/suspend_resume_manager.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/suspend_resume_manager.pl already exists, not overwriting it." ; else install -m 0644 Tools/suspend_resume_manager.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/oarmonitor_sensor.pl ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/oarmonitor_sensor.pl already exists, not overwriting it." ; else install -m 0644 Tools/oarmonitor_sensor.pl $(DESTDIR)$(OARCONFDIR); fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/server_prologue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/server_prologue already exists, not overwriting it." ; else install -m 0755 Scripts/server_prologue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/server_epilogue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/server_epilogue already exists, not overwriting it." ; else install -m 0755 Scripts/server_epilogue $(DESTDIR)$(OARCONFDIR) ; fi
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/Almighty.1 $(DESTDIR)$(MANDIR)/man1/Almighty.1
	install -m 0644 man/man1/oar_mysql_db_init.1 $(DESTDIR)$(MANDIR)/man1/oar_mysql_db_init.1
	install -m 0644 man/man1/oaraccounting.1 $(DESTDIR)$(MANDIR)/man1/oaraccounting.1
	install -m 0644 man/man1/oarmonitor.1 $(DESTDIR)$(MANDIR)/man1/oarmonitor.1
	install -m 0644 man/man1/oarnotify.1 $(DESTDIR)$(MANDIR)/man1/oarnotify.1
	install -m 0644 man/man1/oarproperty.1 $(DESTDIR)$(MANDIR)/man1/oarproperty.1
	install -m 0644 man/man1/oarremoveresource.1 $(DESTDIR)$(MANDIR)/man1/oarremoveresource.1
	install -m 0755 Tools/detect_resources $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oar_resources_init
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oar_resources_init
	chmod 6750 $(DESTDIR)$(SBINDIR)/oar_resources_init
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/detect_resources'\;#;;\
				" $(DESTDIR)$(SBINDIR)/oar_resources_init

user: man
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -m 0755 Qfunctions/oarnodes $(DESTDIR)$(OARDIR)
	install -m 6755 Tools/oardo $(DESTDIR)$(BINDIR)/oarnodes
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(BINDIR)/oarnodes
	chmod 6755 $(DESTDIR)$(BINDIR)/oarnodes
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarnodes'\;#;;\
				" $(DESTDIR)$(BINDIR)/oarnodes
	install -m 0755 Qfunctions/oardel $(DESTDIR)$(OARDIR)
	install -m 6755 Tools/oardo $(DESTDIR)$(BINDIR)/oardel
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(BINDIR)/oardel
	chmod 6755 $(DESTDIR)$(BINDIR)/oardel
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oardel'\;#;;\
				" $(DESTDIR)$(BINDIR)/oardel
	install -m 0755 Qfunctions/oarstat $(DESTDIR)$(OARDIR)
	install -m 6755 Tools/oardo $(DESTDIR)$(BINDIR)/oarstat
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(BINDIR)/oarstat
	chmod 6755 $(DESTDIR)$(BINDIR)/oarstat
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarstat'\;#;;\
				" $(DESTDIR)$(BINDIR)/oarstat
	install -m 0755 Qfunctions/oarsub $(DESTDIR)$(OARDIR)
	install -m 6755 Tools/oardo $(DESTDIR)$(BINDIR)/oarsub
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(BINDIR)/oarsub
	chmod 6755 $(DESTDIR)$(BINDIR)/oarsub
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarsub'\;#;;\
				" $(DESTDIR)$(BINDIR)/oarsub
	install -m 0755 Qfunctions/oarhold $(DESTDIR)$(OARDIR)
	install -m 6755 Tools/oardo $(DESTDIR)$(BINDIR)/oarhold
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(BINDIR)/oarhold
	chmod 6755 $(DESTDIR)$(BINDIR)/oarhold
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarhold'\;#;;\
				" $(DESTDIR)$(BINDIR)/oarhold
	install -m 0755 Qfunctions/oarresume $(DESTDIR)$(OARDIR)
	install -m 6755 Tools/oardo $(DESTDIR)$(BINDIR)/oarresume
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(BINDIR)/oarresume
	chmod 6755 $(DESTDIR)$(BINDIR)/oarresume
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
			     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
			     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
				 s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oarresume'\;#;;\
				" $(DESTDIR)$(BINDIR)/oarresume
	install -m 0755 Tools/oarmonitor_graph_gen.pl $(DESTDIR)$(BINDIR)/oarmonitor_graph_gen
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oardel.1 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarnodes.1 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarresume.1 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarstat.1 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarsub.1 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarhold.1 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oarmonitor_graph_gen.1 $(DESTDIR)$(MANDIR)/man1/oarmonitor_graph_gen.1

node: man
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	install -m 0600 Tools/sshd_config $(DESTDIR)$(OARCONFDIR)
	-chown $(OAROWNER).root $(DESTDIR)$(OARCONFDIR)/sshd_config
	perl -i -pe "s#^XAuthLocation.*#XAuthLocation $(XAUTHCMDPATH)#" $(DESTDIR)$(OARCONFDIR)/sshd_config
	@if [ -f $(DESTDIR)$(OARCONFDIR)/prologue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/prologue already exists, not overwriting it." ; else install -m 0755 Scripts/prologue $(DESTDIR)$(OARCONFDIR) ; fi
	@if [ -f $(DESTDIR)$(OARCONFDIR)/epilogue ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/epilogue already exists, not overwriting it." ; else install -m 0755 Scripts/epilogue $(DESTDIR)$(OARCONFDIR) ; fi
	install -m 0755 Tools/oarnodecheck/oarnodechecklist $(DESTDIR)$(BINDIR)
	perl -i -pe "s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(DESTDIR)$(BINDIR)/oarnodechecklist
	install -m 0755 Tools/oarnodecheck/oarnodecheckquery $(DESTDIR)$(BINDIR)
	perl -i -pe "s#^OARUSER=.*#OARUSER=$(OARUSER)#" $(DESTDIR)$(BINDIR)/oarnodecheckquery
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)/check.d
	install -m 0755 Tools/oarnodecheck/oarnodecheckrun $(DESTDIR)$(OARDIR)
	perl -i -pe "s#^OARUSER=.*#OARUSER=$(OARUSER)#;s#^CHECKSCRIPTDIR=.*#CHECKSCRIPTDIR=$(OARCONFDIR)/check.d#" $(DESTDIR)$(OARDIR)/oarnodecheckrun

build-html-doc: Docs/documentation/
	(cd Docs/documentation && $(MAKE) )

doc: build-html-doc
	install -d -m 0755 $(DESTDIR)$(DOCDIR)
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/documentation/OAR-DOCUMENTATION-USER.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/documentation/OAR-DOCUMENTATION-ADMIN.html $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/schemas/oar_logo.png $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/schemas/db_scheme.png $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/schemas/interactive_oarsub_scheme.png $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/schemas/Almighty.fig $(DESTDIR)$(DOCDIR)/html
	install -m 0644 Docs/schemas/Almighty.ps $(DESTDIR)$(DOCDIR)/html
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/scripts
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager
	install -m 0644 Tools/job_resource_manager.pl $(DESTDIR)$(DOCDIR)/scripts/job_resource_manager/
	install -d -m 0755 $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue
	install -m 0644 Scripts/oar_prologue $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_epilogue $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_prologue_local $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_epilogue_local $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_diffuse_script $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/lock_user.sh $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/
	install -m 0644 Scripts/oar_server_proepilogue.pl $(DESTDIR)$(DOCDIR)/scripts/prologue_epilogue/

draw-gantt:
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	install -d -m 0755 $(DESTDIR)$(WWWDIR)
	install -m 0755 VisualizationInterfaces/DrawGantt/drawgantt.cgi $(DESTDIR)$(CGIDIR)
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	perl -i -pe "s#^web_root: .*#web_root: '$(GANTT_WEB_ROOT)'#" VisualizationInterfaces/DrawGantt/drawgantt.conf 
	perl -i -pe "s#^directory: .*#directory: '$(GANTT_WEB_DIR)'#" VisualizationInterfaces/DrawGantt/drawgantt.conf 
	@if [ -f $(DESTDIR)$(OARCONFDIR)/drawgantt.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/drawgantt.conf already exists, not overwriting it." ; else install -m 0600 VisualizationInterfaces/DrawGantt/drawgantt.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/drawgantt.conf || /bin/true ; fi
	install -d -m 0755 $(DESTDIR)$(WWWDIR)/drawgantt/Icons
	install -d -m 0755 $(DESTDIR)$(WWWDIR)/drawgantt/js
	install -m 0644 VisualizationInterfaces/DrawGantt/Icons/*.png $(DESTDIR)$(WWWDIR)/drawgantt/Icons
	install -m 0644 VisualizationInterfaces/DrawGantt/js/*.js $(DESTDIR)$(WWWDIR)/drawgantt/js
	install -d -m 0755 $(DESTDIR)$(WWWDIR)/drawgantt/cache
	-chown $(WWWUSER) $(DESTDIR)$(WWWDIR)/drawgantt/cache

monika:
	install -d -m 0755 $(DESTDIR)$(CGIDIR)
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	perl -i -pe "s#^css_path = .*#css_path = $(WWW_ROOTDIR)/monika.css#" VisualizationInterfaces/Monika/monika.conf
	@if [ -f $(DESTDIR)$(OARCONFDIR)/monika.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/monika.conf already exists, not overwriting it." ; else install -m 0600 VisualizationInterfaces/Monika/monika.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/monika.conf || /bin/true ; fi
	install -m 0755 VisualizationInterfaces/Monika/monika.cgi $(DESTDIR)$(CGIDIR)
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARCONFDIR)'\;#;;" $(DESTDIR)$(CGIDIR)/monika.cgi
	install -m 0755 VisualizationInterfaces/Monika/userInfos.cgi $(DESTDIR)$(CGIDIR)
	install -m 0644 VisualizationInterfaces/Monika/monika.css $(DESTDIR)$(WWWDIR)
	install -d -m 0755 $(DESTDIR)$(CGIDIR)/monika
	install -m 0644 VisualizationInterfaces/Monika/monika/VERSION $(DESTDIR)$(CGIDIR)/monika
	install -m 0755 VisualizationInterfaces/Monika/monika/*.pm $(DESTDIR)$(CGIDIR)/monika
	install -m 0644 VisualizationInterfaces/Monika/monika/overlib.js $(DESTDIR)$(CGIDIR)/monika

www-conf:
	install -d -m 0755 $(DESTDIR)$(OARCONFDIR)
	@if [ -f $(DESTDIR)$(OARCONFDIR)/apache.conf ]; then echo "Warning: $(DESTDIR)$(OARCONFDIR)/apache.conf already exists, not overwriting it." ; else install -m 0600 VisualizationInterfaces/apache.conf $(DESTDIR)$(OARCONFDIR) ; chown $(WWWUSER) $(DESTDIR)$(OARCONFDIR)/apache.conf || /bin/true ; fi

tools:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -d -m 0755 $(DESTDIR)$(SBINDIR)
	install -m 0755 Oaradmin/oaradmin.rb $(DESTDIR)$(OARDIR)
	install -m 0755 Oaradmin/oar_modules.rb $(DESTDIR)$(OARDIR)
	install -m 0755 Oaradmin/oaradmin_modules.rb $(DESTDIR)$(OARDIR)
	install -m 6750 Tools/oardo $(DESTDIR)$(SBINDIR)/oaradmin
	-chown $(OAROWNER).$(OAROWNERGROUP) $(DESTDIR)$(SBINDIR)/oaradmin
	chmod 6750 $(DESTDIR)$(SBINDIR)/oaradmin
	perl -i -pe "s#Oardir = .*#Oardir = '$(OARDIR)'\;#;;\
                     s#Oarconffile = .*#Oarconffile = '$(OARCONFDIR)/oar.conf'\;#;;\
                     s#Oarxauthlocation = .*#Oarxauthlocation = '$(XAUTHCMDPATH)'\;#;;\
                     s#Cmd_wrapper = .*#Cmd_wrapper = '$(OARDIR)/oaradmin.rb'\;#;;\
                    " $(DESTDIR)$(SBINDIR)/oaradmin
	install -d -m 0755 $(DESTDIR)$(MANDIR)/man1
	install -m 0644 man/man1/oaradmin.1 $(DESTDIR)$(MANDIR)/man1/oaradmin.1

gridlibs:
	install -d -m 0755 $(DESTDIR)$(OARDIR)
	install -m 0644 Oargrid/oargrid_lib.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Oargrid/oargrid_conflib.pm $(DESTDIR)$(OARDIR)
	install -m 0644 Oargrid/oargrid_mailer.pm $(DESTDIR)$(OARDIR)

common-install: common
	@chsh -s $(OARDIR)/oarsh_shell $(OAROWNER)

server-install: sanity-check configuration common-install libs server dbinit

user-install: sanity-check configuration common-install libs user

node-install: sanity-check configuration common-install libs node

doc-install: doc

draw-gantt-install: draw-gantt

monika-install: monika

desktop-computing-cgi-install: sanity-check configuration common-install libs desktop-computing-cgi

desktop-computing-agent-install: desktop-computing-agent

tools-install: sanity-check configuration common-install libs tools

api-install: sanity-check configuration common-install libs api

gridapi-install: sanity-check configuration common-install libs gridlibs gridapi