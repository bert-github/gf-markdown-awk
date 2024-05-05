:
# https://github.github.com/gfm/#example-579

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo][bar][baz]

[baz]: /url1
[bar]: /url2
EOF

cat >$EXPECT <<EOF
<p><a href="/url2">foo</a><a href="/url1">baz</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
