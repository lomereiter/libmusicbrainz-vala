// valac test.vala --pkg musicbrainz-vala
using Musicbrainz;

void main () {
    var artist = Artist.by_id ("b6c18308-82c7-4ec1-a42d-e8488bce6618",
                     new ArtistIncludes () { aliases = true, releases = true });
    stdout.printf (@"$(artist.name)\n$(artist.sort_name)\n$(artist.country)\n");
    foreach (var release in artist.releases) {
        stdout.printf (@"\"$(release.title)\"\n");
        stdout.printf (@"\tID: $(release.id)\n");
    }
}
