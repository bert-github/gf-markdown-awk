# markdown.awk
Awk library to convert GitHub-flavored markdown to HTML or to plain text.

To use this to make a program that converts markdown to HTML, write the following Awk code:

    @include "markdown.awk"
    { lines = lines $0 "\n" }
    END { printf "%s", markdown::to_html(lines) }

(Requires the Gnu version of Awk, because it uses ‘@include’ and namespaces.)

More documentation is included in the `markdown.awk` file.
