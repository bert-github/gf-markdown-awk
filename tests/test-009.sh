:
# https://github.github.com/gfm/#example-9

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
 - foo
   - bar
	 - baz
EOF

cat >$EXPECT <<EOF
<ul>
<li><p>foo</p>
<ul>
<li><p>bar</p>
<ul>
<li><p>baz</p>
</li>
</ul>
</li>
</ul>
</li>
</ul>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
