all: entities_gen webservice_gen

entities_gen:
	valac EntitiesGenerator.vala Utils.vala XmlVisitor.vala --pkg libxml-2.0 --pkg gio-2.0

webservice_gen:
	valac WsGenerator.vala Utils.vala XmlVisitor.vala --pkg libxml-2.0 --pkg gio-2.0 --pkg gee-1.0

clean:
	rm -f WsGenerator EntitiesGenerator
