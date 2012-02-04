string camel (string str) {
    var sb = new StringBuilder ();
    var len = str.length;
    sb.append_c (str[0].toupper ());
    for (int i = 1; i < len; ++i) {
        if ((str[i] == '-') || (str[i] == '_') && (i + 1 < len)) {
            ++i;
            sb.append_c (str[i].toupper ());
        } else {
            sb.append_c (str[i]);
        }
    }
    return sb.str;
}
