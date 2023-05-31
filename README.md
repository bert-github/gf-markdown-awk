# markdown.awk
Awk library to convert GitHub-flavored markdown to HTML or to plain text.

To use this to make a program that converts markdown to HTML, write the following Awk code:

    @include "markdown.awk"
    { lines = lines $0 "\n" }
    END { printf "%s", markdown::to_html(lines) }

(Requires the Gnu version of Awk, because it uses ‘@include’ and namespaces.)

More documentation is included in the `markdown.awk` file.

## What is this for?
There are several programs that convert markdown ([GitHub-flavored markdown](https://github.github.com/gfm/) or other dialects) to HTML and this one isn't the best (see [limitations](limitations) below). So why this code?

It's not a program, but a library. (Although to only requires three lines to make it a program, see above). And in particular it is a library for Awk. It is meant for people who need to add markdown support to an Awk program.

You could, of course, call an external program from your Awk script to convert markdown to HTML. But this library provides two extra functions that may occasionally be handy and that existing programs don't provide. (At least I haven't found any.) And that is the ability to parse inline markdown only, i.e., bold, italics, links, etc.; and the ability to strip markdown from text to retain just the plain text content.

The former is provided by the function `markdown::to_inline_html()`, the latter by the function `markdown::to_text()`.
