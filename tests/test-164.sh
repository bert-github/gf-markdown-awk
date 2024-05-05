:
# https://github.github.com/gfm/#example-164

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[Foo bar]:
<my url>
'title'

[Foo bar]
EOF

cat >$EXPECT <<EOF
<p><a href="my%20url" title="title">Foo bar</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
