The `ef.sh` script is the actual tool I use to generate my personal website
at [joelkleier.com](http://joelkleier.com).

All the other files in this are example documents based off of my personal
site (but should contain only example data).

You'll need Bash, a linux or unix system, and
[pandoc](http://johnmacfarlane.net/pandoc/) installed if you'd like to play
around with it.

If you're running ubuntu, it'd simply be:

    $ sudo apt-get install pandoc
    $ ./ef.sh

If you're running a unix, then you might need to fiddle with some of the `date`
commands used in `ef.sh`.

Here are the parameters/options you can pass into the `ef.sh` script:

  * **-h** displays command usage info
  * **-c** clears cache for a complete rebuild (if a template is changed, you
    should use this)
  * **-v** print the version of the script

Enjoy! or don't...

