:
# https://github.github.com/gfm/#example-644

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
< a><
foo><bar/ >
<foo bar=baz
bim!bop />
EOF

cat >$EXPECT <<EOF
<p>&lt; a&gt;&lt;
foo&gt;&lt;bar/ &gt;
&lt;foo bar=baz
bim!bop /&gt;</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
