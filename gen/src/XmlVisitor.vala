/*
  
  This file is part of libmusicbrainz-vala.
  Copyright (C) 2012 Artem Tarasov
  
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

public abstract class XMLVisitor {
    static const int SHIFT_WIDTH = 4;

    Xml.Doc * doc;
    FileStream? output;

    protected int indent;
    protected string? current_namespace;
    protected string current_classname;

	string infile_dir;

    protected XMLVisitor (string infile, string outfile)
    {

		infile_dir = File.new_for_path (infile).get_parent ().get_path ();

        Xml.Parser.init ();
        doc = Xml.Parser.parse_file (infile);
        indent = 0;

        output = FileStream.open (outfile, "w+");
    }

    ~XMLVisitor () {
        Xml.Parser.cleanup ();
        if (doc != null) delete doc;
    }

    protected void inc () { indent += SHIFT_WIDTH; }
    protected void dec () { indent -= SHIFT_WIDTH; }
    protected void _ (string str) {
        if (output != null) {
            assert (indent >= 0);
            var sb = new StringBuilder ();
            for (int i = 0; i < indent; ++i)
                sb.append_c (' ');
            sb.append (str);
            sb.append_c ('\n');
            output.write (sb.str.data);
        }
    }

    public void process () throws FileError { 
        if (output == null) {
            throw new FileError.FAILED (@"Failed to open output file for writing.");
        }
        if (doc != null) {
            var root = doc -> get_root_element();
            visit (root);
        }
    }
    protected abstract void visit (Xml.Node * node) throws FileError;
    
    protected delegate void ForeachFunc (Xml.Node * node);

    protected void foreach_child (Xml.Node * node, ForeachFunc func) {
        for (Xml.Node * child = node -> children; child != null; child = child -> next)
			if (child -> type == Xml.ElementType.ELEMENT_NODE)
				func (child);
    }

    protected void visit_children (Xml.Node * node) throws FileError {
        for (Xml.Node * child = node -> children; child != null; child = child -> next)
            if (child -> type == Xml.ElementType.ELEMENT_NODE)
                visit (child);
    }
   
    // needed for Vala files only
    protected void visit_root_node (Xml.Node * node) throws FileError {
        indent = 0;
        paste_file ("license_header.inc");
        _ (@"namespace $current_namespace {");
        visit_children (node);
        _ ( "}");
    }

    void paste_file (string filename) {
        var file = infile_dir + "/" + filename;
        var input = FileStream.open (file, "r");
        if (input == null) {
            stderr.printf (@"failed to open $file\n");
        } else {
            string? line;
            while ((line = input.read_line()) != null)
                _ (line);
        }
    }

    protected void visit_verbatim (Xml.Node * node) throws FileError {
        var file = node -> get_prop ("file");
        if (file == null) return;
        paste_file (file);
    }

}
