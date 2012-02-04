public interface Filter {
	public abstract string to_lucene ();
	public static string lucene_escape (string str) {
		string[] to_escape = { "\\", "(", ")", "{", "}", "&&", "||",
							   "+", "-", "!", "[", "]", "^", "\"", 
							   "~", "*", "?", ":" };
		var result = str;
		foreach (var s in to_escape) 
			result = result.replace (s, "\\" + s);
		return result;
	}
	public abstract string entity_name ();
}
