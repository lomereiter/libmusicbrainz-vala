// valac test_async.vala --pkg musicbrainz-vala
using Musicbrainz;

void main () {
    WebService.init ("musicbrainz-vala/0.0.2 (http://github.com/lomereiter)");

    var filter = new ArtistFilter () { name = "Sepultura" };

    filter.search_async.begin (null, null,
    (obj, res) => {
        var artists = filter.search_async.end (res); 

        Artist.lookup_async.begin (artists[0].id, 
            new ArtistIncludes () { relations = { RelationType.TO_ARTIST } },
        (obj, res) => {
            var artist = Artist.lookup_async.end (res);
    
            WebService.burst ();

            foreach (var relation in artist.relations) {
                if (relation.type () == "member of band") {
                    Artist.lookup_async.begin (relation.artist.id,
                        new ArtistIncludes () { relations = { RelationType.TO_ARTIST } }, 
                    (obj, res) => {
                        var member = Artist.lookup_async.end (res); 
                        stdout.printf (@"$(member.name) artist relations:\n");           
                        foreach (var rel in member.relations)
                            stdout.printf ("\t%s: %s\n", rel.type(), rel.artist.name);
                    });
                }
            }
        });
    });

    var loop = new MainLoop ();
    Timeout.add (10 * 1000, () => { loop.quit (); return false; }); // 10 seconds should be enough
    loop.run ();
}
