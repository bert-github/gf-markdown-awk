:
# https://github.github.com/gfm/#example-175

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[ΑΓΩ]: /φου

[αγω]
EOF

cat >$EXPECT <<EOF
<p><a href="/%CF%86%CE%BF%CF%85">αγω</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
