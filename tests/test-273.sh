:
# https://github.github.com/gfm/#example-273

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
- foo
 - bar
  - baz
   - boo
EOF

cat >$EXPECT <<EOF
<ul>
<li>foo</li>
<li>bar</li>
<li>baz</li>
<li>boo</li>
</ul>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
