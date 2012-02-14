// typing recording.artist_credit.name_credits[i].artist 
// is not as easy as recording.artists[i], huh?
public ArtistList artists {
    owned get {
        var list = new ArtistList ();
        foreach (var name_credit in artist_credit.name_credits) {
            list.items += name_credit.artist;
        }
        return list;
    }
}
