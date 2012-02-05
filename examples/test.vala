// valac test.vala --pkg musicbrainz-vala
using Musicbrainz;

void main () {
    WebService.init ("musicbrainz-vala/0.0.2 (http://github.com/lomereiter)");
    var artist = new ArtistFilter () { name = "Crematory", country = "DE" }
                     .search ()[0];
    stdout.printf (@"$(artist.name)\n$(artist.sort_name)\n$(artist.country)\n");

    artist = Artist.by_id (artist.id, 
                new ArtistIncludes () { releases = true,
                                        release_types = { ReleaseType.ALBUM, ReleaseType.EP },
                                        release_statuses = { ReleaseStatus.OFFICIAL }});

    foreach (var release in artist.releases) {
        stdout.printf (@"\"$(release.title)\"\n");
        stdout.printf (@"\tID: $(release.id)\n");
    }
}
