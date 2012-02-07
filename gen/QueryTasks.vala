namespace Musicbrainz {

    internal class QueryAsyncTask : Object, Task {
        string _url;
        public Metadata metadata;
        public QueryAsyncTask (string url) {
            _url = url;
        }
        public async void execute () {
            var msg = new Soup.Message ("GET", _url);
            
            SourceFunc callback = execute.callback;
            WebService.session.queue_message (msg, 
            (session, msg) => {

                metadata = WebService.get_metadata_from_message (msg);
                Idle.add ((owned) callback);
            });
            yield;
        }
    }

}
