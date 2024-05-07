:
# https://github.github.com/gfm/#example-298
# Modified: Enclosed list item text in <p>.

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
- a
- \`\`\`
  b


  \`\`\`
- c
EOF

cat >$EXPECT <<EOF
<ul>
<li>
<p>a</p>
</li>
<li>
<pre><code>b


</code></pre>
</li>
<li>
<p>c</p>
</li>
</ul>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
