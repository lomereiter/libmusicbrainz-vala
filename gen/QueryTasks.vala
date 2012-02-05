namespace Musicbrainz {

    internal class QueryAsyncTask : Object, Task {
        string _url;
        MetadataCallback _cb;
        public QueryAsyncTask (string url, owned MetadataCallback cb) {
            _url = url;
            _cb = (owned) cb;
        }
        public void execute () {
            var msg = new Soup.Message ("GET", _url);
            WebService.session.send_message (msg);
            var metadata = WebService.get_metadata_from_message (msg);

            assert (_cb != null);
            _cb (metadata);
        }
    }

    internal class QuerySyncTask : Object, Task {
        Soup.Message msg;
        public QuerySyncTask (Soup.Message msg) {
            this.msg = msg;
        }
        public void execute () {
            WebService.session.send_message (msg);
        }
    }
}
