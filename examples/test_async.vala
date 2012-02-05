// valac test_async.vala --pkg musicbrainz-vala --pkg posix
using Musicbrainz;

void main () {
    WebService.init ("musicbrainz-vala/0.0.2 (http://github.com/lomereiter)");
    var loop = new MainLoop ();

    new ReleaseFilter () { 
        name = "Ride the Lightning", 
        artist = "Metallica",
        type = ReleaseType.ALBUM
    }.search_async (
        (releases) => {
            Release.by_id_async (
                releases[0].id, 
                new ReleaseIncludes () { 
                    relations = { RelationType.TO_ARTIST }
                },
                (album) => {
                     foreach (var relation in album.relations) {
                         if (relation.type() == "instrument") {
                             Artist.by_id_async (
                                 relation.artist.id, 
                                 new ArtistIncludes () { 
                                        relations = { RelationType.TO_ARTIST }
                                 },
                                 (artist) => {
                                      stdout.printf (@"$(artist.name) is/was:\n");           
                                      foreach (var rel in artist.relations) {
                                          stdout.printf ("\t%s %s\n", 
                                                         rel.type(),
                                                         rel.artist.name);
                                      }
                                 });
                         }
                     }
                });
        });

    loop.run (); // kill me by Ctrl-C
}
