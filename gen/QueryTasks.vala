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

    internal class QueryAsyncTask : Object, Task {
        string _url;
        public Metadata metadata = null;
        public Soup.KnownStatusCode status_code;
        public QueryAsyncTask (string url) {
            _url = url;
        }

        void get_metadata_from_message (Soup.Message message) {
            // WebService will use the status to throw exceptions
            status_code = (Soup.KnownStatusCode) message.status_code;
            
            if (status_code != Soup.KnownStatusCode.OK) return; 

            string xml = (string)(message.response_body.flatten ().data);

            Xml.Doc * doc = Xml.Parser.parse_doc (xml);
            metadata = new Metadata.from_node (doc -> get_root_element ());
            delete doc;
        }

        public async void execute () {
            var msg = new Soup.Message ("GET", _url);
            
            SourceFunc callback = execute.callback;
            WebService.session.queue_message (msg, 
            (session, msg) => {
                get_metadata_from_message (msg);
                Idle.add ((owned) callback);
            });
            yield;
        }
    }

}
