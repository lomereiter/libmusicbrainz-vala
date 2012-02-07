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
