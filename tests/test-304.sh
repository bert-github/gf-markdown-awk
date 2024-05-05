:
# https://github.github.com/gfm/#example-304

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
1. \`\`\`
   foo
   \`\`\`

   bar
EOF

cat >$EXPECT <<EOF
<ol>
<li>
<pre><code>foo
</code></pre>
<p>bar</p>
</li>
</ol>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
