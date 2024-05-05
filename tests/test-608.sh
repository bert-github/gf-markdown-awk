:
# https://github.github.com/gfm/#example-608

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
<made-up-scheme://foo,bar>
EOF

cat >$EXPECT <<EOF
<p><a href="made-up-scheme://foo,bar">made-up-scheme://foo,bar</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
