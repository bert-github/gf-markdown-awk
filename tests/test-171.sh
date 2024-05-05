:
# https://github.github.com/gfm/#example-171

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo]: /url\\bar\\*baz "foo\\"bar\\baz"

[foo]
EOF

cat >$EXPECT <<EOF
<p><a href="/url%5Cbar*baz" title="foo&quot;bar\\baz">foo</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
