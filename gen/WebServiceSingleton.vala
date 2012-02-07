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

    static const bool DEBUG = false;

    public class WebService {

        static const uint QUERIES = 10;
        static const uint TIME_INTERVAL = 10000000;
        
        TaskExecuter task_executer = new TaskExecuter (TIME_INTERVAL, QUERIES);

        static WebService _instance = null;
        internal static Soup.SessionAsync session = new Soup.SessionAsync ();

        string server;
        int port;

        /**
         * Is to be called before making any queries to MusicBrainz.
         * @param user_agent string identifying your application to MusicBrainz webservice
         * @param server address of MusicBrainz server
         * @param port port to connect to
         */
        public static void init (string user_agent, 
                                 string server="http://musicbrainz.org",
                                 int port=80) 
        {
            lock (_instance) {
                if (_instance == null) {
                    _instance = new WebService ();
                    _instance.session.user_agent = user_agent;
                    _instance.server = server;
                    _instance.port = port;
                } 
            }
        }

        public static unowned WebService instance () {
            return _instance;
        }

        internal static Metadata get_metadata_from_message (Soup.Message message) {
            string xml = (string)(message.response_body.flatten ().data);

            if (DEBUG) { stdout.printf ("%s\n", xml); }

            Xml.Parser.init ();
            Xml.Doc * doc = Xml.Parser.parse_doc (xml);
            Metadata result = new Metadata.from_node (doc -> get_root_element ());
            Xml.Parser.cleanup ();
            delete doc;
            
            return result;
        }

        async Metadata query_async (string suffix) {
            var url = @"$server:$port/ws/2/$suffix";
            if (DEBUG) { stdout.printf ("%s\n", url); }
            var task = new QueryAsyncTask (url);
            yield task_executer.execute_task (task);
            return task.metadata;
        }

        Metadata query (string suffix) {
            Metadata result = null;
            var loop = new MainLoop ();
            query_async.begin (suffix, (obj, res) => {
                result = query_async.end (res);
                loop.quit ();
            });
            loop.run ();
            return result;
        }

        static string gen_lookup_query (string entity, string id, string? includes_str) {
            var inc = includes_str;
            if (inc == null) return @"$entity/$id";
            return @"$entity/$id?inc=$inc";
        }

        /** 
         * Returns a Metadata instance containing information about the entity
         * which MusicBrainz ID is specified.
         * @param entity entity type
         * @param id MusicBrainz ID of the entity
         * @param includes_str controls the amount of information to get from MusicBrainz
         */
        public static Metadata lookup_query (string entity, string id, string? includes_str) {
            return _instance.query (gen_lookup_query (entity, id, includes_str));
        }

        public static async Metadata lookup_query_async (string entity, 
                                                         string id, string? includes_str) {
            var metadata = yield _instance.query_async (
                                    gen_lookup_query (entity, id, includes_str));
            return metadata;
        }

        static string gen_search_query (string entity, string lucene_query,
                                        int? limit, int? offset) 
        {
            var str = @"$entity?query=$lucene_query";
            if (limit != null)
                str += @"&limit=$limit";
            if (offset != null)
                str += @"&offset=$offset";
            return str;
        }

        /**
         * Returns a Metadata instance from which search results can be retrieved by
         * accessing corresponding property.
         * @param entity name of entity in MusicBrainz notation (e.g, "release-group")
         * @param lucene_query query in Lucene syntax
         * @param limit limits number of results returned
         * @param offset the offset in the list of results
         */
        public static Metadata search_query (string entity, string lucene_query,
                                             int? limit, int? offset)
        {
            return _instance.query (gen_search_query (entity, lucene_query, limit, offset));
        }

        public static async Metadata search_query_async (string entity, string lucene_query,
                                                         int? limit, int? offset)
        {
            return yield _instance.query_async (gen_search_query (entity, lucene_query, limit, offset));
        }

        /**
         * Allows to burst a few queries without violating 
         * MusicBrainz rate limiting rules. 
         * @param queries_to_burst the number of queries to burst, <= 10
         */
        public static void burst (uint queries_to_burst=10) {
            assert (queries_to_burst <= 10);
            _instance.task_executer.enter_burst_mode (queries_to_burst);            
        }
    }

}
