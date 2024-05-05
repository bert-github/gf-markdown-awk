:
# https://github.github.com/gfm/#example-183

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
# [Foo]
[foo]: /url
> bar
EOF

cat >$EXPECT <<EOF
<h1><a href="/url">Foo</a></h1>
<blockquote>
<p>bar</p>
</blockquote>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
