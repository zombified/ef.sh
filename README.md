# ef.sh

This is a bash utility intended to facilitate the generation of a static website.

A prime example is [joelkleier.com](https://joelkleier.com) -- the main motivation
for the tool to exist in the first place.

Version 2.x is significantly different than version 1.x -- take a look at the
[1.x branch](https://github.com/zombified/ef.sh/tree/1.x) if you're curious how
the first version worked.

The `someplace.com` folder in this repo is an example of a _very_ basic site
generated with this tool.

## pre-reqs:

You need this installed:

  * [shyaml](https://pypi.python.org/pypi/shyaml) for reading yaml front matter
  * GNU `date` from the coreutils project (usually installed by default on linux machines, on OS X coreutils needs to be installed with brew or equivalent)

The default configuration is setup to expect the following:

  * [asciidoctor](http://asciidoctor.org/) for asciidoc formatted files
  * [pandoc](http://pandoc.org/) for markdown and many other formats

## Basic usage

The help should be pretty explanitory for the command usage:

    $ ef.sh help
    Version: 2.0.0

    USAGE
    -----
    ef.sh help    -- print this help text
    ef.sh build   -- build files that have changed since last run
    ef.sh fresh   -- rebuild entire site regardless of timestamps
    ef.sh init    -- generate a default efshrc and template files in the $PWD
                        (this operation will overwrite any existing files)
    -----
    The script looks for a efshrc file in the $PWD
    The script requires 'asciidoctor' (by default) to be installed and available on your PATH for asciidoc support.
    The script requires 'pandoc' (by default) to be installed and available on your PATH for markdown support.
    The script requires 'shyaml' to be installed. 'pip install shyaml'
    The script requires the coreutils GNU date command, on OS X 'brew install coreutils' and set EFSH_DATE_CMD to 'gdate' in your efshrc

## Configuration

The basic principle of the utility is:

  1. scan the PWD directory recursively
  2. pass each file through a mapped handler (mapped via file extension)
     * if no handler for a file, the file is ignored

There are some built-in handlers:

  * pandoc -- mapped to *.md by default
  * asciidoctor -- mapped to *.adoc by default
  * copy -- mapped, by default, to *.css, *.js, *.gif, *.jpg, *.jpeg, *.png, *.svg, and *.html
  * blogindex -- mapped, by default, to *.blogindex
  * siteindex -- mapped, by default, to *.siteindex
  * rssatom -- mapped, by default, to *.rssatom

All of these handlers are defined as a set of bash methods with specially
formatted names.

You associate a handler with a file extension in a sites `efshrc` file.


## TODO's

  1. make a way to specify a default handler for unknown filetypes
  2. make generated items the rss/atom handler be generated from templates instead of being hardcoded
  3. make a blog index item generated from a template instead of being hardcoded
  4. make it so handlers can be modularized in some fashion
  5. consider the possibility of doing something with tags

See anything else that you think should be added, changed, or fixed? Create an issue!

Enjoy! or don't...

