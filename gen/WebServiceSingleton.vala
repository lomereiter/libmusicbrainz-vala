namespace Musicbrainz {

    public delegate void MetadataCallback (Metadata md);

    static const bool DEBUG = false;

    public class WebService {
        
        TaskExecuter task_executer = new TaskExecuter ();

        static WebService _instance = null;
        internal static Soup.SessionSync session = new Soup.SessionSync ();

        string server;
        int port;

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

        void query_async (string suffix, owned MetadataCallback cb) {
            var url = @"$server:$port/ws/2/$suffix";
            if (DEBUG) { stdout.printf ("%s\n", url); }
            task_executer.add_task ( new QueryAsyncTask (url, (owned) cb) );
        }

        Metadata query (string suffix) {
            var url = @"$server:$port/ws/2/$suffix";
            if (DEBUG) { stdout.printf ("%s\n", url); }
            var message = new Soup.Message ("GET", url);
            task_executer.add_task_and_wait ( new QuerySyncTask (message));
            return get_metadata_from_message (message);
        }


        static string gen_lookup_query (string entity, string id, Includes? includes) {
            var inc = "";
            if (includes != null)
                inc = includes.to_string ();
            return @"$entity/$id?$inc";
        }

        public static Metadata lookup_query (string entity, string id, Includes? includes) {
            return instance ().query (gen_lookup_query (entity, id, includes));
        }

        public static void lookup_query_async (string entity, string id, Includes? includes,
                                               owned MetadataCallback callback)
        {
            instance ().query_async (gen_lookup_query (entity, id, includes), 
                                     (owned) callback);
        }

        static string gen_search_query (string entity, Filter filter, 
                                        int? limit, int? offset) 
        {
            var str = @"$entity?query=$(filter.to_lucene ())";
            if (limit != null)
                str += @"&limit=$limit";
            if (offset != null)
                str += @"&offset=$offset";
            return str;
        }

        public static Metadata search_query (string entity, Filter filter,
                                             int? limit, int? offset)
        {
            return instance ().query (gen_search_query (entity, filter, limit, offset));
        }

        public static void search_query_async (string entity, Filter filter,
                                               int? limit, int? offset,
                                               owned MetadataCallback callback)
        {
            instance ().query_async (gen_search_query (entity, filter, limit, offset),
                                     (owned) callback);
        }
    }

}
