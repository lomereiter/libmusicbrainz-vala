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

namespace Musicbrainz {

    public errordomain MBError {
        BAD_REQUEST,
        NOT_FOUND,
        SERVICE_UNAVAILABLE,
        UNKNOWN_REASON
    }

    static const bool DEBUG = true;

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
            Xml.Parser.init ();
        }

        public static unowned WebService instance () {
            return _instance;
        }

        async Metadata query_async (string suffix) throws MBError {
            var url = @"$server:$port/ws/2/$suffix";
            if (DEBUG) { stdout.printf ("%s\n", url); }
            var task = new QueryAsyncTask (url);
            yield task_executer.execute_task (task);

            var status = task.status_code;
            if (Soup.KnownStatusCode.OK == status) {
                return task.metadata;
            }
            var phrase = Soup.status_get_phrase (status);
            switch (status) {
                case Soup.KnownStatusCode.BAD_REQUEST:
                    throw new MBError.BAD_REQUEST (phrase);
                case Soup.KnownStatusCode.NOT_FOUND:
                    throw new MBError.NOT_FOUND (phrase);
                case Soup.KnownStatusCode.SERVICE_UNAVAILABLE:
                    throw new MBError.SERVICE_UNAVAILABLE (phrase);
                // TODO: maybe add some other status codes
                default:
                    throw new MBError.UNKNOWN_REASON (phrase);
            }
        }

        Metadata query (string suffix) throws MBError {
            Metadata result = null;
            var loop = new MainLoop ();
            MBError? error = null;
            query_async.begin (suffix, (obj, res) => {
                try {
                    result = query_async.end (res);
                } catch (MBError e) {
                    error = (owned) e;
                }
                loop.quit ();
            });
            loop.run ();
            if (error != null) {
                throw error;
            }
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
        public static Metadata lookup_query (string entity, string id, 
                                             string? includes_str) throws MBError 
        {
            return _instance.query (gen_lookup_query (entity, id, includes_str));
        }

        public static async Metadata lookup_query_async (string entity, string id, 
                                                         string? includes_str) throws MBError 
        {
            var metadata = yield _instance.query_async (
                                    gen_lookup_query (entity, id, includes_str));
            return metadata;
        }

        static string gen_search_query (string entity, string lucene_query,
                                        int? limit, int? offset) 
        {
            var str = @"$entity?query=$lucene_query";
            assert (limit == null || limit <= 100);
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
                                             int? limit, int? offset) throws MBError
        {
            return _instance.query (gen_search_query (entity, lucene_query, limit, offset));
        }

        public static async Metadata search_query_async (string entity, string lucene_query,
                                                         int? limit, int? offset) throws MBError
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
