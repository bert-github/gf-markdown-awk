:
# https://github.github.com/gfm/#example-48

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
Foo bar
# baz
Bar foo
EOF

cat >$EXPECT <<EOF
<p>Foo bar</p>
<h1>baz</h1>
<p>Bar foo</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
