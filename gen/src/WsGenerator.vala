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

    void visit_includes (Xml.Node * node) {
        foreach_child (node, (includes) => {
            var class_name = camel (includes -> name + "-includes");
            _ (@"public class $class_name : Includes {");
            inc (); 
            foreach_child (includes, (field) => {
                var name = field -> name;
                var type = field -> get_prop ("type");
                if (type == null) {
                    type = "bool";
                } else {
                    type = camel (type);
                }
                var default_value = type.has_suffix ("[]") ? "{}" : "false";
                _ (@"public $type $name = $default_value;");
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
                    }
                });
                _ (@"return \"inc=\" + string.joinv (\"+\", includes);");
            dec ();
            _ ( "}"); // end of method
            dec (); 
            _ ("}"); // end of class
        });
    }

    void visit_filters (Xml.Node * node) {
        foreach_child (node, (filter) => {
            var class_name = camel (filter -> name + "-filter");
            _ (@"public class $class_name : Filter {");
            inc (); 
                foreach_child (filter, (field) => {
                    var type = field -> get_prop ("type");
                    if (type == null) type = "string";
                    var name = field -> name;
                    _ (@"public $type? $name = null;");
                });
                _ ( "public string entity_name () {");
                _ (@"    return \"$(MBify (filter -> name))\";");
                _ ( "}");
                _ (@"public string to_lucene () {"); //TODO:make me internal
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
                            case "int":
                                expression = @"$name";
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
                    _ (@"return string.joinv (\" AND \", parameters);");
                dec ();
                _ ( "}"); // end of method;
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
