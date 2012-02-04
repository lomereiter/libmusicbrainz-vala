public bool contains_disc_id (string disc_id) {
	bool contains = false;
	foreach (var disc in discs) {
		if (disc.id == disc_id) {
			contains = true;
			break;
		}
	}
	return contains;
}
