:
# https://github.github.com/gfm/#example-547

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo<http://example.com/?search=][ref]>

[ref]: /uri
EOF

cat >$EXPECT <<EOF
<p>[foo<a href="http://example.com/?search=%5D%5Bref%5D">http://example.com/?search=][ref]</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
