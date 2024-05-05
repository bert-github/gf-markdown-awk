:
# https://github.github.com/gfm/#example-649

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
foo <!-- not a comment -- two hyphens -->
EOF

cat >$EXPECT <<EOF
<p>foo &lt;!-- not a comment -- two hyphens --&gt;</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
