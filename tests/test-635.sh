:
# https://github.github.com/gfm/#example-635

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
xmpp:foo@bar.baz/txt/bin
EOF

cat >$EXPECT <<EOF
<p><a href="xmpp:foo@bar.baz/txt">xmpp:foo@bar.baz/txt</a>/bin</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
