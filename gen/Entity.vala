namespace Musicbrainz {

    public class Entity {
        Gee.Map<string, string> _ext_attributes = new Gee.HashMap<string,string> ();
        Gee.Map<string, string> _ext_elements = new Gee.HashMap<string, string> ();
        Gee.Map<string, string> ext_attributes { get { return _ext_attributes; } }
        Gee.Map<string, string> ext_elements { get { return _ext_elements; } }

        protected virtual void parse_root_node (Xml.Node * node) {
        }
        protected virtual void parse_attribute (string name, string value) {
            stderr.printf ("Unexpected attribute: %s\n", name);
        }
        protected virtual void parse_element (Xml.Node * node) {
            stderr.printf ("Unexpected element: %s\n", node -> name);
        }

        protected void parse (Xml.Node * node) {
            for (Xml.Attr* attr = node -> properties; attr != null; attr = attr -> next) {
                var name = attr -> name;
                var val = node -> get_prop (name);
                if (attr -> ns != null && attr -> ns -> prefix == "ext") {
                    _ext_attributes[name] = val;
                } else {
                    parse_attribute (name, val);
                }
            }
            for (Xml.Node* elem = node -> children; elem != null; elem = elem -> next) {
                if (elem -> type != Xml.ElementType.ELEMENT_NODE) continue;
                var name = elem -> name;
                var val = elem -> get_content ();
                if (name.has_prefix ("ext:")) {
                    _ext_elements[name.substring (4)] = val;
                } else {
                    parse_element (elem);
                }
            }
        }

        public string to_string () {
            var sb = new StringBuilder ();
            if (!_ext_attributes.is_empty) {
                sb.append ("Ext attrs:\n");
                foreach (var kv in _ext_attributes.entries)
                    sb.append (@"$(kv.key) = $(kv.value)\n");
            }
            if (!_ext_elements.is_empty) {
                sb.append ("Ext elements:\n");
                foreach (var kv in _ext_elements.entries)
                    sb.append (@"$(kv.key) = $(kv.value)\n");
            }
            return sb.str;
        }

    }

} // namespace
