:
# https://github.github.com/gfm/#example-541

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo [bar](/uri)][ref]

[ref]: /uri
EOF

cat >$EXPECT <<EOF
<p>[foo <a href="/uri">bar</a>]<a href="/uri">ref</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
