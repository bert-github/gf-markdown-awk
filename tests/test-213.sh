:
# https://github.github.com/gfm/#example-213
# Modified: Enclosed list item text in <p>.

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
> - foo
- bar
EOF

cat >$EXPECT <<EOF
<blockquote>
<ul>
<li>
<p>foo</p>
</li>
</ul>
</blockquote>
<ul>
<li>
<p>bar</p>
</li>
</ul>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
