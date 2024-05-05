:
# https://github.github.com/gfm/#example-489

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
**a<http://foo.bar/?q=**>
EOF

cat >$EXPECT <<EOF
<p>**a<a href="http://foo.bar/?q=**">http://foo.bar/?q=**</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
