/*
  
  EntitiesGenerator, generator of entities code for MusicBrainz
  Copyright (C) 2012 Artem Tarasov
  
  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
    
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA 
  
*/

string uncamel (string text) {
    var sb = new StringBuilder ();
    var len = text.length;
    for (int i = 0; i < len; i++) {
        if (i > 1 && text[i].isupper() &&
            ((text[i-1].islower()) || (i+1 < len && text[i+1].islower())))
            sb.append_c ('_');
        sb.append_c (text[i].tolower());
    }
    return sb.str;
}


string lowercase (Xml.Node * node) {
    var name = node -> get_prop ("name");
    var uppername = node -> get_prop ("uppername");
    if (uppername != null) {
        name = uncamel (uppername);
    }
    name = lowercase_str (name);
    if (name.has_suffix ("_list")) {
        name = plural (name.substring (0, name.length - 5));
    }
    return name;
}

string lowercase_str (string str) {
    return str.replace("-", "_").replace(":", "_");
}

string camelize (Xml.Node * node) {
    var uppername = node -> get_prop ("uppername");
    if (uppername != null) {
        return uppername;
    }
    return camel (node -> get_prop("name"));
}

public class EntitiesGenerator : XMLVisitor {

    delegate void SpecialCaseFunc ();
    SpecialCaseFunc elements_special_case = null;
    SpecialCaseFunc attributes_special_case = null;

    public EntitiesGenerator (string infile, string outfile)
    {
        base (infile, outfile);
        current_namespace = "Musicbrainz";
        header_filename = null; // FIXME
    }

    protected override void visit (Xml.Node * node) throws FileError {
        inc ();
        switch (node -> name) {
            case "generate":
                visit_root_node (node); break;
            case "class":
                visit_class (node); break;
            case "property":
                visit_property (node); break;
            case "list":
                visit_list (node); break;
            case "verbatim":
                visit_verbatim (node); break;
            case "root":
                visit_root (node); break;
            case "attributes":
                visit_attributes (node); break;
            case "elements":
                visit_elements (node); break;
        }
        dec ();
    }

    void generate_from_node_constructor (Xml.Node * node) {
        _ (@"public $current_classname.from_node (Xml.Node * node) {");//TODO:make me internal
        _ ( "    if (node != null) parse (node);");
        for (Xml.Node * child = node -> children; child != null; 
             child = child -> next) {
             if (child -> name == "root") {
                  _ ( "    parse_root_node (node);");
                  break;
             }
         }
        _ ( "}");
    }

    void generate_by_id_static_method (Xml.Node * node) {
        if (node -> get_prop ("lookup") != "true") return;
        var c = current_classname;
        var mb_name = node -> get_prop ("name");
        var name = lowercase_str (mb_name);
        _ (@"public static $c lookup (string id, $(c)Includes? includes=null) {");
        _ (@"    return WebService.lookup_query (\"$mb_name\", id, includes.to_string ()).$name;"); 
        _ ( "}");
        _ (@"public static async $c lookup_async (string id, $(c)Includes? includes=null) {");
        _ (@"    var metadata = yield WebService.lookup_query_async (\"$mb_name\", id, ");
        _ ( "                                                        includes.to_string ());");
        _ (@"    return metadata.$name;"); 
        _ ( "}");
    }

    protected void visit_class (Xml.Node * node) throws FileError {
        current_classname = camelize (node);
        _ (@"public class $current_classname : Entity {");
        inc (); generate_from_node_constructor (node); 
                generate_by_id_static_method (node);   dec ();
        visit_children (node);
        _ ( "}"); 
    }

    protected void visit_root (Xml.Node * node) throws FileError {
        dec (); visit_children (node); inc ();
        _ (@"internal override void parse_root_node (Xml.Node * node) {");
        foreach_property (node, (type, vala_type, name, mb_name) => {
            inc (); generate_conversion ("_" + name, type, vala_type); dec ();
        });
        _ ( "}");
    }

    // type - string | integer | double | object
    // vala_type - type of property in Vala code
    // name - name of property in Vala code
    // mb_name - name of property in Musicbrainz XML
    delegate void PropertyFunc (string type, string vala_type, string name, string mb_name);

    void foreach_property (Xml.Node * node, PropertyFunc func) {
        foreach_child (node, (property) => {
            if (property -> name == "property") {
                var mb_name = property -> get_prop ("name"); 
                var name = property_name (property);

                func (property -> get_prop ("type"), property_type (property),
                      name, mb_name);

                property = property -> next;
            }
        });
    }

    SpecialCaseFunc cases_to_skip (Xml.Node * node) {
        return () => {
            foreach_child (node, (child) => {
                if (child -> name == "skip") {
                    var mb_name = child -> get_prop ("name");
                    _ (@"case \"$mb_name\": break;");
                }
            });
        };
    }

    protected void visit_attributes (Xml.Node * node) throws FileError {
        SpecialCaseFunc special_case = (owned) attributes_special_case;
        var skip_cases = cases_to_skip (node);
        attributes_special_case = () => { 
            skip_cases ();
            if (special_case != null) special_case ();
        };
        dec (); visit_children (node); inc (); // generate properties
        _ (@"internal override void parse_attribute (string name, string value) {");
        inc (); _ ( "switch (name) {"); inc ();
                attributes_special_case ();
                foreach_property (node, (type, vala_type, name, mb_name) => {
                    _ (@"case \"$mb_name\":");
                    inc ();
                    switch (type) {
                        case "string":
                            _ (@"_$name = value;"); break;
                        default:
                            _ (@"_$name = $vala_type.parse (value);"); break;
                    }
                    _ ( "break;"); dec ();
                });

                _ ( "default:");
                _ (@"    stderr.printf (\"Unrecognized $current_classname " +
                                                "attribute: %s\\n\", name);");
                _ ( "    break;"); dec ();
                _ ( "}"); dec ();// end of switch statement
        _ ( "}"); // end of method
    }

    void generate_conversion (string name, string type, string vala_type) {
        switch (type) {
            case "object":
                _ (@"$name = new $vala_type.from_node (node);");
                break;
            case "string":
                _ (@"$name = node -> get_content ();");
                break;
            case "Time":
                _ (@"$name = Time ();");
                _ ( "var date = node -> get_content ();");
                _ ( "var sep = date.index_of_char ('-');");
                _ (@"$name.year = int.parse (date.substring (0, sep)) - 1900;");
                _ ( "if (sep == -1) break;");
                _ ( "date = date.substring (sep + 1);");
                _ ( "sep = date.index_of_char ('-');");
                _ (@"$name.month = int.parse (date.substring (0, sep)) - 1;");
                _ ( "if (sep == -1) break;");
                _ ( "date = date.substring (sep + 1);");
                _ ( "sep = date.index_of_char ('-');");
                _ (@"$name.day = int.parse (date);");
                break;
            default:
                _ (@"$name = $vala_type.parse (node -> get_content ());");
                break;
        }
    }

    public void visit_elements (Xml.Node * node) throws FileError {
        SpecialCaseFunc special_case = (owned) elements_special_case;
        elements_special_case = () => { 
            cases_to_skip (node) ();
            if (special_case != null) special_case ();
        };

        dec (); visit_children (node); inc (); // generate properties

        _ (@"internal override void parse_element (Xml.Node * node) {");
        inc (); _ ( "unowned string name = node -> name;");
                _ ( "switch (name) {"); inc ();
                elements_special_case ();
                foreach_property (node, (type, vala_type, name, mb_name) => {
                    _ (@"case \"$mb_name\":");
                    inc (); generate_conversion ("_" + name, type, vala_type);
                            _ ( "break;"); dec ();
                });
                _ ( "default:");
                _ (@"    stderr.printf (\"Unrecognized $current_classname " +
                                             "element: %s\\n\", name);");
                _ ( "    break;"); dec ();
                _ ( "}"); dec ();// end of switch statement
        _ ( "}"); // end of method
    }

    private string property_name (Xml.Node * node) {
        return lowercase (node);
    }

    private string property_type (Xml.Node * node) {
        var type = node -> get_prop ("type"); 
        switch (type) {
            case "object":
                type = camelize (node);
                break;
            case "integer":
                type = "int";
                break;
            default:
                break;
        }
        return type;
    }

    protected void visit_property (Xml.Node * node) {
        var name = property_name (node); 
        var type = property_type (node);
        if (type.has_suffix ("List")) {
            _ (@"$type _$name = new $type ();");
        } else {
            _ (@"$type? _$name = null;");
        }
        if (name == "type") {
            // Special case because Vala doesn't allow property 'type'
            // So we just make a function instead of property.
            _ (@"public $type type () { return _type; }");
        } else {
            _ (@"public $type $name { get { return _$name; } }");
        }
    }

	static Xml.Node * find_child (Xml.Node * node, string child_name) {
        Xml.Node * child = node -> children;
        while (child != null && child -> name != child_name)
            child = child -> next;
		return child;
	}

    protected void visit_list (Xml.Node * node) throws FileError {
        var elem_class = camelize (node);
        var elem_mb_name = node -> get_prop ("name");
        var c = elem_class + "List";
        current_classname = c;

        // add <elements/> if list has no elements
		Xml.Node * child = find_child (node, "elements");
        if (child == null) {
            child = new Xml.Node (node -> ns, "elements");
            node -> add_child (child);
        }

		// add <attributes>...</attributes>
		child = find_child (node, "attributes");
		if (child == null) {
			child = new Xml.Node (node -> ns, "attributes");
			node -> add_child (child);
		}
		Xml.Node * count = new Xml.Node (node -> ns, "property");
		count -> set_prop ("name", "count");
		count -> set_prop ("type", "integer");
		Xml.Node * offset = new Xml.Node (node -> ns, "property");
		offset -> set_prop ("name", "offset");
		offset -> set_prop ("type", "integer");
		child -> add_child (count);
		child -> add_child (offset);

        _ (@"public class $c : Entity {");
        inc (); _ (@"internal $elem_class[] items = {};");
				_ ( "public int size { get { return items.length; } }");
				_ (@"public $elem_class get (int i) { return items[i]; }");
        generate_from_node_constructor (node); dec ();
        elements_special_case = () => {
            _ (@"case \"$elem_mb_name\":");
            _ (@"    items += new $elem_class.from_node (node);");
            _ ( "    break;");
        };
        visit_children (node);
        elements_special_case = null;
        _ ( "}");
    }

} // EntitiesGenerator

void main (string[] args) {
    try {
        string infile = args.length > 1 ? args[1] : "entities.xml";
        string outfile = args.length > 2 ? args[2] : "Entities.vala";
        new EntitiesGenerator (infile, outfile).process ();
    } catch (FileError e) {
        stderr.printf ("%s\n", e.message);
    }
}
