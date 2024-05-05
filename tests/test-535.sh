:
# https://github.github.com/gfm/#example-535

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo<http://example.com/?search=](uri)>
EOF

cat >$EXPECT <<EOF
<p>[foo<a href="http://example.com/?search=%5D(uri)">http://example.com/?search=](uri)</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
