all:
	make source_generators
	make sources
	make library

source_generators:
	cd gen/src && make

sources:
	rm -rf src/
	mkdir src/
	gen/src/EntitiesGenerator gen/entities.xml src/Entities.vala
	gen/src/WsGenerator gen/webservice.xml src/WebService.vala

NAME=musicbrainz-vala
LIBNAME=lib$(NAME)
SOURCE_FILES=Entity.vala Filter.vala Includes.vala WebServiceSingleton.vala
GEN_FILES=Entities.vala WebService.vala
SOURCES=$(GEN_FILES) $(SOURCE_FILES)
PACKAGES=--pkg gee-1.0 --pkg libxml-2.0 --pkg libsoup-2.4
VALAC=valac-0.14

library:
	cd gen && cp $(SOURCE_FILES) ../src
	cd src && $(VALAC) --library $(LIBNAME).so -o $(LIBNAME).so -X -fPIC -X --shared $(SOURCES) --vapi $(NAME).vapi -H $(NAME).h $(PACKAGES)
	rm -rf lib/
	mkdir lib
	cp gen/$(NAME).deps lib/
	cp gen/$(NAME).pc lib/
	mv src/$(NAME).h src/$(LIBNAME).so src/$(NAME).vapi lib/

clean:
	cd gen/src && make clean
	rm -rf src/ lib/

install:
	cp lib/$(LIBNAME).so /usr/lib/
	cp lib/$(NAME).vapi /usr/share/vala/vapi
	cp lib/$(NAME).deps /usr/share/vala/vapi
	cp lib/$(NAME).h /usr/include
	cp lib/$(NAME).pc /usr/lib/pkgconfig/

uninstall:
	rm -f /usr/lib/$(LIBNAME).so
	rm -f /usr/share/vala/vapi/$(NAME).vapi
	rm -f /usr/share/vala/vapi/$(NAME).deps
	rm -f /usr/include/$(NAME).h
	rm -f /usr/lib/pkgconfig/$(NAME).pc
