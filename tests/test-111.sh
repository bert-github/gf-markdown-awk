:
# https://github.github.com/gfm/#example-111

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
foo
---
~~~
bar
~~~
# baz
EOF

cat >$EXPECT <<EOF
<h2>foo</h2>
<pre><code>bar
</code></pre>
<h1>baz</h1>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
