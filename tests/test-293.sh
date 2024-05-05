:
# https://github.github.com/gfm/#example-293

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
1. a

  2. b

    3. c
EOF

cat >$EXPECT <<EOF
<ol>
<li>
<p>a</p>
</li>
<li>
<p>b</p>
</li>
</ol>
<pre><code>3. c
</code></pre>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
