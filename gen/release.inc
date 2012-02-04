public MediumList media_matching_disc_id (string disc_id) {
	var ret = new MediumList ();
	foreach (var medium in mediums) {
		if (medium.contains_disc_id (disc_id)) {
			ret.items += medium;
		}
	}
	return ret;
}
