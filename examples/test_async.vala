// valac test_async.vala --pkg musicbrainz-vala
using Musicbrainz;

async void print_members_of_sepultura () {
   
    try {
        var artists = yield new ArtistFilter () { name = "Sepultura" }.search_async ();

        var include_relations_to_artist = new ArtistIncludes () { 
                                              relations = { RelationType.TO_ARTIST } 
                                          };

        var artist = yield Artist.lookup_async (artists[0].id, 
                                                include_relations_to_artist);
        WebService.burst ();

        foreach (var relation in artist.relations) {
            if (relation.type () == "member of band") {
                var member = yield Artist.lookup_async (relation.artist.id, 
                                                        include_relations_to_artist);
                stdout.printf (@"$(member.name) artist relations:\n");           
                foreach (var rel in member.relations)
                    stdout.printf ("\t%s: %s\n", rel.type(), rel.artist.name);
            }
        }
    } catch (MBError e) {
        stdout.printf ("Error: %s\n", e.message);
    }
}

void main () {
    WebService.init ("musicbrainz-vala/0.0.2 (http://github.com/lomereiter)");

    var loop = new MainLoop ();
    Timeout.add (10 * 1000, () => { loop.quit (); return false; }); // 10 seconds should be enough

    print_members_of_sepultura (); 

    loop.run ();
}
