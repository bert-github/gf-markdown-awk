:
# https://github.github.com/gfm/#example-288
# Modified: Enclosed list item text in <p>.

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
- foo
- bar

<!-- -->

- baz
- bim
EOF

cat >$EXPECT <<EOF
<ul>
<li>
<p>foo</p>
</li>
<li>
<p>bar</p>
</li>
</ul>
<!-- -->
<ul>
<li>
<p>baz</p>
</li>
<li>
<p>bim</p>
</li>
</ul>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
