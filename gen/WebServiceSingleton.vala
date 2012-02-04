namespace Musicbrainz {

    public class WebService {

        static const string USER_AGENT = "musicbrainz-vala/0.0.1 (http://github.com/lomereiter)";
        static const ulong TIME_INTERVAL = 1000 * 1000 * 2; // 2 seconds

        public int? port = null; // TODO: validation
        public string? server = null;

        DateTime? last_request_time = null;

        private WebService () {
            if (server == null) server = "http://musicbrainz.org";
            if (port == null) port = 80;
        }

        static WebService _instance = null;

        public static unowned WebService instance () {
            lock (_instance) {
                if (_instance == null) {
                    _instance = new WebService ();
                } 
            }
            return _instance;
        }

        Metadata query (string suffix) {
            var url = @"$server:$port/ws/2/$suffix";

            var session = new Soup.SessionSync ();
            session.user_agent = USER_AGENT;

            var message = new Soup.Message ("GET", url);

            lock (last_request_time) {
                var now = new DateTime.now_local ();
                if (last_request_time == null) {
                    last_request_time = now;
                } else {
                    ulong delta = (ulong)now.difference (last_request_time);

                    if (delta < TIME_INTERVAL)
                        Thread.usleep (TIME_INTERVAL - delta);

                    last_request_time = new DateTime.now_local ();
                }
            }
            session.send_message (message);
            // TODO: exceptions

            string xml = (string)(message.response_body.flatten ().data);
            
            Xml.Parser.init ();
            Xml.Doc * doc = Xml.Parser.parse_doc (xml);
            Metadata result = new Metadata.from_node (doc -> get_root_element ());
            Xml.Parser.cleanup ();
            delete doc;
            
            return result;
        }

        public Metadata lookup_query (string entity, string id, Includes? includes) {
            var inc = "";
            if (includes != null)
                inc = includes.to_string ();
            return query (@"$entity/$id?$inc");
        }
    }

}
