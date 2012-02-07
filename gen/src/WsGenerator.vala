/*
  
  This file is part of libmusicbrainz-vala.
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

class WsGenerator : XMLVisitor {

    delegate string RewritingRule (string str);

    RewritingRule MBify = (str) => { return str.replace ("_", "-"); };

    public WsGenerator (string infile, string outfile) {
        base (infile, outfile);
        current_namespace = "Musicbrainz";
    }

    protected override void visit (Xml.Node * node) throws FileError {
        inc ();
        var name = node -> name;
        switch (name) {
            case "generate":
                visit_root_node (node); break;
            case "implies":
                visit_implies (node); break;
            case "enums":
                visit_enums (node); break;
            case "rewrite_rules":
                visit_rules (node); break;
            case "includes":
                visit_includes (node); break;
            case "filters":
                visit_filters (node); break;
            case "verbatim":
                visit_verbatim (node); break;
        }
        dec ();
    }

    void visit_enums (Xml.Node * node) {
        foreach_child (node, (child) => {
            var enum_name = camel (child -> name);
            _ (@"public enum $enum_name {");
            inc ();
            string[] elements = {};
            foreach_child (child, (element) => {
                elements += element -> name.up ();
            });
            _ (@"$(string.joinv (", ", elements));");

            _ (@"internal string to_mb () {");
            inc (); _ ( "string result = null;");
                    _ ( "switch (this) {");
                    inc ();
                    foreach_child (child, (element) => {
                        var name = element -> name.up ();
                        _ (@"case $name:");
                        _ (@"    result = \"$(MBify (element -> name))\"; break;");
                    });
                    dec ();
                    _ ( "}");
                    _ ( "return result;");
            dec ();
            _ ( "}"); // end of method
            dec ();
            _ ( "}"); // end of enum
        });
    }

    void visit_rules (Xml.Node * node) {
        foreach_child (node, (rule) => {
            switch (rule -> name) {
                case "suffix":
                    RewritingRule old_mbify = (owned) MBify;
                    MBify = (str) => {
                        var suffix = rule -> get_prop ("match");
                        var replacement = rule -> get_prop ("replace");
                        var prepend = rule -> get_prop ("prepend");
                        if (prepend == null) prepend = "";
                        if (str.has_suffix (suffix)) {
                            return old_mbify (prepend + str.substring (0, str.length - suffix.length) 
                                                + replacement);
                        }
                        return old_mbify (str);
                    };
                    break;
                case "prefix":
                    RewritingRule old_mbify = (owned) MBify;
                    MBify = (str) => {
                        var prefix = rule -> get_prop ("match");
                        var replacement = rule -> get_prop ("replace");
                        var append = rule -> get_prop ("append");
                        if (append == null) append = "";
                        if (str.has_prefix (prefix)) {
                            return old_mbify (replacement + str.substring (prefix.length) 
                                                + append);
                        }
                        return old_mbify (str);
                    };
                    break;
                default:
                    RewritingRule old_mbify = (owned) MBify;
                    MBify = (str) => {
                        if (str == rule -> name) {
                            return rule -> get_prop ("replace");
                        } else {
                            return old_mbify (str);
                        }
                    };
                    break;
            }
        });
    }

    Gee.HashMap <string, Xml.Node*> _implies = new Gee.HashMap <string, Xml.Node*> ();
    void visit_implies (Xml.Node * implies) {
        foreach_child (implies, (entity) => {
            _implies[entity -> name] = entity;
        });
    }

    void postprocess (Xml.Node * includes) {
        // Takes _implications_ into account.
        // An implication is, for instance, release => release_types.
        // That is, if some *Includes class has field 'release' it also 
        // has field 'release_types' which is to be added.
        bool need_to_add_suffix = false;
        Gee.Set <string> props = new Gee.HashSet <string> (); 
        foreach_child (includes, (field) => { props.add (field -> name); });
        Xml.Node*[] fields_to_add = {};
        foreach_child (includes, (field) => {
            if (_implies.has_key (field -> name)) {
                if (!need_to_add_suffix) {
                    _ ( "var suffix = \"\";");
                }
                need_to_add_suffix = true;

                var name = field -> name;
                foreach_child (_implies[name], (implication) => {
                    var impl_name = implication -> name;
                    if (!props.contains (impl_name)) {
                        props.add (impl_name);
                        fields_to_add += implication;
                        var mb_name = MBify (impl_name);
                        // Here we make an assumption that right part of the implication
                        // is an array. Currently this is the case but might change in future.
                        _ (@"if ($impl_name.length != 0) {"); inc ();
                        _ ( "string[] mbified = {};");
                        _ (@"foreach (var item in $impl_name)");
                        _ ( "    mbified += item.to_mb ();");
                        _ (@"suffix += \"&$mb_name=\" + string.joinv (\"|\", mbified);");
                        dec (); _ ( "}");
                    }
                });
            }
        });
        _ (@"var result = string.joinv (\"+\", includes);");
        if (need_to_add_suffix) {
            _ ( "result += suffix;");
        }
        _ ( "return result;");
        dec ();
        _ ( "}"); // end of method
        foreach (var field in fields_to_add) {
            add_includes_field (field -> name, field -> get_prop ("type"));
        }
    }

    void add_includes_field (string name, string? type) {
        var _type = type == null ? "bool" : camel (type);
        // Currently, includes fields are either arrays or bools.
        var default_value = _type.has_suffix ("[]") ? "{}" : "false";
        _ (@"public $_type $name = $default_value;");
    }

    void visit_includes (Xml.Node * node) {
        foreach_child (node, (includes) => {
            var class_name = camel (includes -> name + "-includes");
            _ (@"public class $class_name {");
            inc (); 
            foreach_child (includes, (field) => {
                var name = field -> name;
                var type = field -> get_prop ("type");
                add_includes_field (name, type);
            });
            _ ( "public string to_string () {");
            inc ();
                _ ( "string[] includes = {};");
                foreach_child (includes, (field) => {
                    var type = field -> get_prop ("type");
                    if (type == null) type = "bool";
                    var name = field -> name;
                    switch (type) {
                        case "bool":
                            _ (@"if ($name) includes += \"$(MBify (name))\";"); 
                            break;
                        case "relation_type[]":
                            _ (@"foreach (var rel_type in $name) includes += rel_type.to_mb ();");
                            break;
                        // release_types and release_statuses are processed in postprocess
                    }
                });
                postprocess (includes); // end of method is there
            dec (); 
            _ ("}"); // end of class
        });
    }

    void visit_filters (Xml.Node * node) {
        foreach_child (node, (filter) => {
            var class_name = camel (filter -> name);
            var entity_name = MBify (filter -> name);
            _ (@"public class $(class_name)Filter : Filter {");
            inc (); 
                foreach_child (filter, (field) => {
                    var type = field -> get_prop ("type");
                    if (type == null) type = "string";
                    var name = field -> name;
                    _ (@"public $type? $name = null;");
                });
                _ (@"internal string to_lucene () {");
                inc (); 
                    _ ("string[] parameters = {};");
                    foreach_child (filter, (field) => {
                        var type = field -> get_prop ("type");
                        if (type == null) type = "string";

                        var name = field -> name;

                        var mb_name = field -> get_prop ("param");
                        if (mb_name == null) mb_name = MBify (name);
                        
                        _ (@"if ($name != null)"); inc ();

                        string expression = null; 
                        switch (type) {
                            case "string":
                                expression = @"$name";
                                break;
                            case "int":
                                expression = @"$name.to_string ()";
                                break;
                            case "Time":
                                expression = @"$name.format (\"%F\")"; 
                                break;
                            default:
                                expression = @"$name.to_mb ()";
                                break;
                        }
                        _ (@"parameters += @\"$mb_name:$$(lucene_escape ($expression))\";");
                        dec ();
                    });
                    //       currently filters are quite limited
                    //       compared to queries in Lucene syntax
                    //       and use only AND conjunction
                    _ (@"return string.joinv (\" AND \", parameters);");
                dec ();
                _ ( "}"); // end of method;

                var list_name = plural (filter -> name);
    
                _ (@"public $(class_name)List search (int? limit=null, int? offset=null) {");
                _ (@"    return WebService.search_query (\"$entity_name\",");
                _ (@"                to_lucene (), limit, offset).$list_name;");
                _ ( "}");

                _ (@"public async $(class_name)List search_async (int? limit=null, int? offset=null) {");
                _ (@"    var metadata = yield WebService.search_query_async (\"$entity_name\",");
                _ ( "                                              to_lucene (), limit, offset);");
                _ (@"    return metadata.$list_name;");
                _ ( "}");
                            
            dec (); 
            _ ("}"); // end of class
        });
    }
}

void main (string[] args) {
    try {
        string infile = args.length > 1 ? args[1] : "webservice.xml";
        string outfile = args.length > 2 ? args[2] : "WebService.vala";
        new WsGenerator (infile, outfile).process ();
    } catch (FileError e) {
        stderr.printf ("%s\n", e.message);
    }
}
