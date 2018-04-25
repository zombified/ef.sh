#!/usr/bin/env bash

EFSH_VERSION=2.0.0


# $1 file get yaml frontmatter from
efsh_get_yaml_frontmatter() {
    local infile=$1

    #local yaml=$(cat $infile | sed -n -e '/---/,/---/p' | tail -n +2 | sed \$d)
    local yaml=$(cat $infile | python -c 'exec("import sys\na=sys.stdin.readlines()\nfor l in a[1:]:\n\tif l.strip() == \"---\":\n\t\tsys.exit(0)\n\tprint l.strip()")')

    echo "$yaml"
}

# $1 file get content from
efsh_get_content() {
    local infile=$1

    local filecontent=$(cat $infile | sed -e '1,/---/d')

    echo "$filecontent"
}

efsh_get_temp_file() {
    # try to use a standard unix command to get the temp file, but otherwise
    # use python if it's available
    if hash mktemp 2>/dev/null ; then
        mktemp
    else
        if hash python 2>/dev/null ; then
            echo "import tempfile ; temp = tempfile.NamedTemporaryFile() ; print(temp.name)" | python -
        else
            echo "ERROR: need python to make temp file because no 'mktemp' found"
            exit 1
        fi
    fi
}

# $1 == `$EFSH_DATE_CMD` to format to YYYY-mm-dd
efsh_format_date() {
    # old stories tend to add milliseconds, so strip those first
    local justdatetime=$(echo "$1" | sed -e 's/\..*//')
    echo -n `$EFSH_DATE_CMD -d "$justdatetime" +%Y-%m-%d`
}



efsh_check_handler_pandoc() {
    if ! hash pandoc 2>/dev/null ; then
        echo "ERROR: pandoc command cannot be found"
        exit 1
    fi
}

efsh_check_handler_asciidoctor() {
    if ! hash asciidoctor 2>/dev/null ; then
        echo "ERROR: asciidoctor command cannot be found"
        exit 1
    fi
}

efsh_check_handler_copy() {
    if ! hash cp 2>/dev/null ; then
        echo "ERROR: cp command cannot be found"
        exit 1
    fi
}

efsh_check_handler_blogindex() {
    return 0
}

efsh_check_handler_rssatom() {
    return 0
}

efsh_check_handler_jsonfeed() {
    return 0
}

efsh_check_handler_siteindex() {
    return 0
}


# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_asciidoctor() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR/$fixed1/$2"
    local outfile="$outdir/index.html"
    mkdir -p "$outdir"
    shopt -s extglob; infile="${infile//+(\/)//}"
    shopt -s extglob; outfile="${outfile//+(\/)//}"

    local yamlfront=$(efsh_get_yaml_frontmatter "$infile")
    local filecontent=$(efsh_get_content "$infile")

    local efsh_title=$(echo "$yamlfront" | shyaml get-value title)
    efsh_title=$(echo "$efsh_title" | sed 's/\//\\\//g')
    local efsh_description=$(echo "$yamlfront" | shyaml get-value description)
    efsh_description=$(echo "$efsh_description" | sed 's/\//\\\//g')
    local efsh_date=$(echo "$yamlfront" | shyaml get-value date)
    efsh_date=$(efsh_format_date "$efsh_date")

    # ascii doc only converts files, so throw the contents into a temporary file
    local tmpin=$(efsh_get_temp_file)
    echo "$filecontent" > $tmpin

    echo "[building (asciidoctor)] $fixed1/$2.$3 -> $fixed1/$2/index.html"
    local output=$(asciidoctor -o - --no-header-footer "$tmpin")

    local head=$(cat "$EFSH_TMPL_HEAD" | sed -e 's/{{title}}/'"${efsh_title}"'/g' -e 's/{{description}}/'"${efsh_description}"'/g' -e 's/{{date}}/'"${efsh_date}"'/g')
    local tail=$(cat "$EFSH_TMPL_TAIL" | sed -e 's/{{title}}/'"${efsh_title}"'/g' -e 's/{{description}}/'"${efsh_description}"'/g' -e 's/{{date}}/'"${efsh_date}"'/g')
    echo "$head" > "$outfile"
    echo "${output}" >> "$outfile"
    echo "$tail" >> "$outfile"

    rm "$tmpin"
}

# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_pandoc() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR/$fixed1/$2"
    local outfile="$outdir/index.html"
    mkdir -p "$outdir"
    shopt -s extglob; infile="${infile//+(\/)//}"
    shopt -s extglob; outfile="${outfile//+(\/)//}"

    local yamlfront=$(efsh_get_yaml_frontmatter "$infile")
    local filecontent=$(efsh_get_content "$infile")

    local efsh_title=$(echo "$yamlfront" | shyaml get-value title)
    efsh_title=$(echo "$efsh_title" | sed 's/\//\\\//g')
    local efsh_description=$(echo "$yamlfront" | shyaml get-value description)
    efsh_description=$(echo "$efsh_description" | sed 's/\//\\\//g')
    local efsh_date=$(echo "$yamlfront" | shyaml get-value date)
    efsh_date=$(efsh_format_date "$efsh_date")

    echo "[building (pandoc)] $fixed1/$2.$3 -> $fixed1/$2/index.html"
    local output=$(echo "$filecontent" | pandoc -f markdown -t html5)

    local head=$(cat "$EFSH_TMPL_HEAD" | sed -e 's/{{title}}/'"${efsh_title}"'/g' -e 's/{{description}}/'"${efsh_description}"'/g' -e 's/{{date}}/'"${efsh_date}"'/g')
    local tail=$(cat "$EFSH_TMPL_TAIL" | sed -e 's/{{title}}/'"${efsh_title}"'/g' -e 's/{{description}}/'"${efsh_description}"'/g' -e 's/{{date}}/'"${efsh_date}"'/g')
    echo "$head" > "$outfile"
    echo "${output}" >> "$outfile"
    echo "$tail" >> "$outfile"
}

# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_copy() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR/$fixed1"
    local outfile="$outdir/$2.$3"
    mkdir -p "$outdir"
    shopt -s extglob; infile="${infile//+(\/)//}"
    shopt -s extglob; outfile="${outfile//+(\/)//}"

    echo "[building (copy)] $fixed1/$2.$3"
    cp "$infile" "$outfile"
}

# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_blogindex() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR/$fixed1"
    local outfile="$outdir/index.html"
    mkdir -p "$outdir"

    if [ -e "$EFSH_LASTGEN" ] ; then
        local newnames=$(eval "find $EFSH_SRC_DIR/$fixed1/ \( -name *.md -o -name *.adoc \) -newer \"$EFSH_LASTGEN\"")
        local cntnn=0
        for NN in ${newnames[@]} ; do
            cntnn=$((cntnn + 1))
        done
        if [ "$cntnn" -le "0" ] ; then
            echo "[building (blog index)] nothing changed, nothing to build."
            return 0
        fi
    fi

    echo "[building (blog index)] $fixed1/index.html"
    local blogentries=$(find $EFSH_SRC_DIR/$fixed1/ \( -name *.md -o -name *.adoc \) | sort -r)
    local output=""
    for F in ${blogentries[@]} ; do
        #echo "- processing: $F"
        local frelpath=${F#$EFSH_SRC_DIR}
        local ffolder=$(dirname $frelpath)
        local ffilename=$(basename $frelpath)
        local ffileext=${ffilename##*.}
        local ffilename=${ffilename%.*}

        local yamlfront=$(efsh_get_yaml_frontmatter "$F")
        local posttitle=$(echo "$yamlfront" | shyaml get-value title)
        local postdate=$(echo "$yamlfront" | shyaml get-value date)
        postdate=$(efsh_format_date "$postdate")
        local postdesc=$(echo "$yamlfront" | shyaml get-value description)

        output+="<p><img class='linkicon' src='/static/icons/blueprint_speak.svg' /><a href='./${ffilename}/'>(${postdate}) ${posttitle}</a></p>\n"
        output+="<p class='info'>${postdesc}</p>"
    done

    local efsh_title="BLOG"
    local efsh_description=""
    local efsh_date=$(date +%Y-%m-%d)

    local head=$(cat "$EFSH_TMPL_HEAD" | sed -e 's/{{title}}/'"${efsh_title}"'/g' -e 's/{{description}}/'"${efsh_description}"'/g' -e 's/{{date}}/'"${efsh_date}"'/g')
    local tail=$(cat "$EFSH_TMPL_TAIL" | sed -e 's/{{title}}/'"${efsh_title}"'/g' -e 's/{{description}}/'"${efsh_description}"'/g' -e 's/{{date}}/'"${efsh_date}"'/g')
    echo "$head" > "$outfile"
    echo -e "${output}" >> "$outfile"
    echo "$tail" >> "$outfile"
}

# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_rssatom() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR"
    local outfile_rss="$outdir/rss.xml"
    local outfile_atom="$outdir/atom.xml"
    mkdir -p "$outdir"

    if [ -e "$EFSH_LASTGEN" ] ; then
        local newnames=$(eval "find $EFSH_SRC_DIR/$fixed1/ \( -name *.md -o -name *.adoc \) -newer \"$EFSH_LASTGEN\"")
        local cntnn=0
        for NN in ${newnames[@]} ; do
            cntnn=$((cntnn + 1))
        done
        if [ "$cntnn" -le "0" ] ; then
            echo "[building (rss/atom)] nothing changed, nothing to build."
            return 0
        fi
    fi

    echo "[building (rss/atom feeds)] rss.xml"
    local blogentries=$(find $EFSH_SRC_DIR/$fixed1/ \( -name *.md -o -name *.adoc \) | sort -r)
    local outputrss=""
    local outputatom=""
    for F in ${blogentries[@]} ; do
        #echo "- processing: $F"
        local frelpath=${F#$EFSH_SRC_DIR}
        local ffolder=$(dirname $frelpath)
        local ffilename=$(basename $frelpath)
        local ffileext=${ffilename##*.}
        local ffilename=${ffilename%.*}

        local yamlfront=$(efsh_get_yaml_frontmatter "$F")
        local posttitle=$(echo "$yamlfront" | shyaml get-value title)
        local postdate_fromfile=$(echo "$yamlfront" | shyaml get-value date | tr -d '\n')
        postdate_fromfile=$(efsh_format_date "$postdate_fromfile")
        # note, the '-R' is for --rfc-2822, which is a gnu date option
        local postdate_rss=$($EFSH_DATE_CMD -d "$postdate_fromfile" -R)
        local postdate_atom=$($EFSH_DATE_CMD -d "$postdate_fromfile" --rfc-3339='date')
        local postdesc=$(echo "$yamlfront" | shyaml get-value description)

        outputrss+="<item>\n\t<title><![CDATA[${posttitle}]]></title>\n\t<link>${EFSH_BASE_URL}/blog/${ffilename}</link>\n\t<description><![CDATA[${postdesc}]]></description>\n\t<pubDate>${postdate_rss}</pubDate>\n\t<guid>${EFSH_BASE_URL}/blog/${ffilename}</guid>\n</item>\n"
        outputatom+="<entry>\n\t<title><![CDATA[${posttitle}]]></title>\n\t<link href='${EFSH_BASE_URL}/blog/${ffilename}' />\n\t<summary><![CDATA[${postdesc}]]></summary>\n\t<updated>${postdate_atom}</updated>\n\t<id>${EFSH_BASE_URL}/blog/${ffilename}</id>\n\t<author>\n\t\t<name>${EFSH_AUTHOR}</name>\n\t\t<email>${EFSH_EMAIL}</email>\n\t</author>\n</entry>\n"
    done

    local efsh_date=$(echo -n `$EFSH_DATE_CMD --rfc-3339='date'`)

    # note: need to use non '/' in sed since output's will have them
    local rss=$(cat "$EFSH_TMPL_RSS" | sed -e 's|{{items}}|'"${outputrss}"'|g')
    local atom=$(cat "$EFSH_TMPL_ATOM" | sed -e 's|{{updated}}|'"${efsh_date}"'|g' -e 's|{{entries}}|'"${outputatom}"'|g') > "$outfile_atom"
    echo "$rss" > "$outfile_rss"
    echo "$atom" > "$outfile_atom"
}

# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_jsonfeed() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR"
    local outfile_json="$outdir/feed.json"
    mkdir -p "$outdir"

    if [ -e "$EFSH_LASTGEN" ] ; then
        local newnames=$(eval "find $EFSH_SRC_DIR/$fixed1/ \( -name *.md -o -name *.adoc \) -newer \"$EFSH_LASTGEN\"")
        local cntnn=0
        for NN in ${newnames[@]} ; do
            cntnn=$((cntnn + 1))
        done
        if [ "$cntnn" -le "0" ] ; then
            echo "[building (json feed)] nothing changed, nothing to build."
            return 0
        fi
    fi

    echo "[building (json feed)] feed.json"
    local blogentries=$(find $EFSH_SRC_DIR/$fixed1/ \( -name *.md -o -name *.adoc \) | sort -r)
    local outputjson="["
    local cntr=0
    for F in ${blogentries[@]} ; do
        #echo "- processing: $F"
        local frelpath=${F#$EFSH_SRC_DIR}
        local ffolder=$(dirname $frelpath)
        local ffilename=$(basename $frelpath)
        local ffileext=${ffilename##*.}
        local ffilename=${ffilename%.*}

        local yamlfront=$(efsh_get_yaml_frontmatter "$F")
        local posttitle=$(echo "$yamlfront" | shyaml get-value title)
        local postdate_fromfile=$(echo "$yamlfront" | shyaml get-value date | tr -d '\n')
        postdate_fromfile=$(efsh_format_date "$postdate_fromfile")
        # note, the '-R' is for --rfc-2822, which is a gnu date option
        local postdate_json=$($EFSH_DATE_CMD -d "$postdate_fromfile" --rfc-3339='date')
        local postdesc=$(echo "$yamlfront" | shyaml get-value description)
        local postdesc_esc=${postdesc//\"/\\\\\"}

        if [ "$cntr" -gt "0" ] ; then
            outputjson+=","
        fi
        cntr=$(($cntr+1))

        outputjson+="{\"id\":\"${EFSH_BASE_URL}/blog/${ffilename}\",\"url\":\"${EFSH_BASE_URL}/blog/${ffilename}\",\"title\":\"${posttitle}\",\"content_html\":\"${postdesc_esc}\",\"date_published\":\"${postdate_json}\"}"
    done
    outputjson+="]"

    # note: need to use non '/' in sed since output's will have them
    local jsonfeed=$(cat "$EFSH_TMPL_JSONFEED" | sed -e 's|{{items}}|'"${outputjson}"'|g')
    echo "$jsonfeed" > "$outfile_json"
}

# $1 == source directory
# $2 == source filename (without extension)
# $3 == source extension
efsh_build_handler_siteindex() {
    local fixed1=$1
    fixed1="${fixed1:1:${#fixed1}-1}"
    local infile="$EFSH_SRC_DIR/$fixed1/$2.$3"
    local outdir="$EFSH_BUILD_DIR"
    local outfile="$outdir/index.html"
    mkdir -p "$outdir"

    echo "[building (siteindex)] $fixed1/$2.$3 -> $fixed1/$2.html"
    local output=$(cat $infile)

    local efsh_title=''

    local head=$(cat "$EFSH_TMPL_IHEAD" | sed -e 's/{{title}}/'"${efsh_title}"'/g')
    local tail=$(cat "$EFSH_TMPL_ITAIL")
    echo "$head" > "$outfile"
    echo "${output}" >> "$outfile"
    echo "$tail" >> "$outfile"
}

# CONFIGURE
efsh_loadconfig() {
    if ! hash shyaml 2>/dev/null ; then
        echo "ERROR: 'shyaml' not installed. 'pip install shyaml'"
        exit 1
    fi


    # defaults
    EFSH_AUTHOR="Some Body"
    EFSH_EMAIL="somebody@someplace.com"
    EFSH_BASE_URL="https://someplace.com"
    EFSH_DATE_CMD=date
    EFSH_SRC_DIR=$PWD/src
    EFSH_BUILD_DIR=$PWD/build
    EFSH_LASTGEN=$PWD/.lastgen
    EFSH_EXT=(".md" ".adoc" ".css" ".js" ".gif" ".jpg" ".jpeg" ".png" ".svg" ".html" ".blogindex" ".rssatom" ".jsonfeed" ".siteindex")
    EFSH_EXT_HANDLERS=(pandoc asciidoctor copy copy copy copy copy copy copy copy blogindex rssatom jsonfeed siteindex)
    EFSH_TMPL_HEAD=$PWD/tmpl_head.html
    EFSH_TMPL_TAIL=$PWD/tmpl_tail.html
    EFSH_TMPL_IHEAD=$PWD/tmpl_ihead.html
    EFSH_TMPL_ITAIL=$PWD/tmpl_itail.html
    EFSH_TMPL_RSS=$PWD/tmpl_rss.xml
    EFSH_TMPL_ATOM=$PWD/tmpl_atom.xml
    EFSH_TMPL_JSONFEED=$PWD/tmpl_jsonfeed.json

    # load local config
    if [ -e "$PWD/efshrc" ] ; then
        source "$PWD/efshrc"
    fi

    # check to make sure all extensions can be handled
    for handler in ${EFSH_EXT_HANDLERS[@]}; do
        if ! hash $handler 2>/dev/null ; then
            if ! eval "efsh_check_handler_$handler" ; then
                exit 1
            fi
        fi
    done
}


# HELP
efsh_help() {
    echo "Version: ${EFSH_VERSION}"
    echo ""
    echo "USAGE"
    echo "-----"
    echo "${0##*/} help    -- print this help text"
    echo "${0##*/} build   -- build files that have changed since last run"
    echo "${0##*/} fresh   -- rebuild entire site regardless of timestamps"
    echo "${0##*/} init    -- generate a default efshrc and template files in the \$PWD"
    echo "                    (this operation will overwrite any existing files)"
    echo "-----"
    echo "The script looks for a efshrc file in the \$PWD"
    echo "The script requires 'asciidoctor' (by default) to be installed and available on your PATH for asciidoc support."
    echo "The script requires 'pandoc' (by default) to be installed and available on your PATH for markdown support."
    echo "The script requires 'shyaml' to be installed. 'pip install shyaml'"
    echo "The script requires the coreutils GNU date command, on OS X 'brew install coreutils' and set EFSH_DATE_CMD to 'gdate' in your efshrc"
}

# INIT
efsh_init() {
    # generate default efshrc
    cat > efshrc << _end_
# NOTE: this is effectively a bash script. You could technically put anything
# here you want to run at the very beginning of efsh2 execution (after default
# variables have been set).

#EFSH_AUTHOR="Some Body"
#EFSH_EMAIL="somebody@someplace.com"
#EFSH_BASE_URL="https://someplace.com"
#EFSH_DATE_CMD=date
#EFSH_SRC_DIR=\$PWD/src
#EFSH_BUILD_DIR=\$PWD/build
#EFSH_BUILD_DIR=\$PWD/build
#EFSH_LASTGEN=\$PWD/.lastgen
#EFSH_EXT=(".md" ".adoc" ".css" ".js" ".gif" ".jpg" ".jpeg" ".png" ".svg" ".html" ".blogindex" ".rssatom" ".jsonfeed" ".siteindex")
#EFSH_EXT_HANDLERS=(pandoc asciidoctor copy copy copy copy copy copy copy copy blogindex rssatom jsonfeed siteindex)
#EFSH_TMPL_HEAD=\$PWD/tmpl_head.html
#EFSH_TMPL_TAIL=\$PWD/tmpl_tail.html
#EFSH_TMPL_IHEAD=\$PWD/tmpl_ihead.html
#EFSH_TMPL_ITAIL=\$PWD/tmpl_itail.html
#EFSH_TMPL_RSS=\$PWD/tmpl_rss.xml
#EFSH_TMPL_ATOM=\$PWD/tmpl_atom.xml
#EFSH_TMPL_JSONFEED=\$PWD/tmpl_jsonfeed.json
_end_

    # generate default templates, if they don't exist
    # HEAD
    cat > "$EFSH_TMPL_HEAD" << _end_
<!DOCTYPE html>
<html lang='en'>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

        <title>{{title}}</title>

        <link href="./" rel="home start" />
        <link href="/atom.xml" type="application/atom+xml" rel="alternate" title="Atom Feed" />
        <link href="/rss.xml" type="application/rss+xml" rel="alternate" title="RSS Feed" />
        <link href="/feed.json" type="application/json" rel="alternate" title="JSON Feed" />
    </head>
    <body>
_end_
    # TAIL
    cat > "$EFSH_TMPL_TAIL" << _end_
    </body>
</html>
_end_

    # IHEAD
    cat > "$EFSH_TMPL_IHEAD" << _end_
<!DOCTYPE html>
<html lang='en'>
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

        <title>{{title}}</title>

        <link href="./" rel="home start" />
        <link href="/atom.xml" type="application/atom+xml" rel="alternate" title="Atom Feed" />
        <link href="/rss.xml" type="application/rss+xml" rel="alternate" title="RSS Feed" />
        <link href="/feed.json" type="application/json" rel="alternate" title="JSON Feed" />
    </head>
    <body>
_end_
    # ITAIL
    cat > "$EFSH_TMPL_ITAIL" << _end_
    </body>
</html>
_end_


    # RSS
    cat > "$EFSH_TMPL_RSS" << _end_
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
    <title>A Site.</title>
    <description></description>
    <language>en</language>
    <link>https://someplace.com</link>
    <atom:link href="https://someplace.com/rss.xml" rel="self" type="application/rss+xml" />
{{items}}
</channel>
</rss>
_end_
    # ATOM
    cat > "$EFSH_TMPL_ATOM" << _end_
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
    <title>A Site.</title>
    <subtitle></subtitle>
    <link href="https://someplace.com/atom.xml" rel="self" />
    <link href="https://someplace.com" />
    <id>http://someplace.com/</id>
    <updated>{{updated}}</updated>
{{entries}}
</feed>
_end_
    # JSONFEED
    cat > "$EFSH_TMPL_JSONFEED" << _end_
{
    "user_comment": "This feed allows you to view all the posts from this site in a feed reader that supports the JSON Feed format. To add this feed to your reader, copy the following URL: https://someplace.com/feed.json",

    "version": "https://jsonfeed.org/version/1",
    "title": "A Site.",
    "home_page_url": "https://sompleace.com",
    "feed_url": "https://someplace.com/feed.json",
    "items": {{items}}
}
_end_
}

# BUILD
efsh_build() {
    if [ ! -e $EFSH_SRC_DIR ] ; then
        echo "$EFSH_SRC_DIR not found"
        exit 1
    fi

    # make build directory if it doesn't exist
    mkdir -p $EFSH_BUILD_DIR

    # generate `find` search parameters for file names
    local searchparams="\( "
    for i in ${!EFSH_EXT[@]}; do
        if [ "$i" -ne "0" ]; then
            searchparams+=" -o "
        fi
        searchparams+="-name \*${EFSH_EXT[$i]}"
    done
    searchparams+=" \)"

    # only generate files that are newer than the last build time
    if [ -e "$EFSH_LASTGEN" ] ; then
        local names=$(eval "find $EFSH_SRC_DIR $searchparams -newer \"$EFSH_LASTGEN\"")
    else
        local names=$(eval "find $EFSH_SRC_DIR $searchparams")
    fi

    for F in ${names[@]} ; do
        srcrelpath=${F#$EFSH_SRC_DIR}
        srcfolder=$(dirname $srcrelpath)
        srcfilename=$(basename $srcrelpath)
        srcfileext=${srcfilename##*.}
        srcfilename=${srcfilename%.*}
        for H in ${!EFSH_EXT[@]}; do
            if [ "${EFSH_EXT[$H]}" = ".$srcfileext" ] ; then
                eval "efsh_build_handler_${EFSH_EXT_HANDLERS[$H]} \"$srcfolder\" \"$srcfilename\" \"$srcfileext\""
            fi
        done
    done

    echo -n "$($EFSH_DATE_CMD)" >> "$EFSH_LASTGEN"

    echo "[build] All done."
}





efsh_loadconfig
case $1 in
    build)
        # touch so they get checked to see if they need
        # rebuilding every time (will be skipped if no blog entries change)
        touch $EFSH_SRC_DIR/blog/index.blogindex
        touch $EFSH_SRC_DIR/blog/xml.rssatom
        touch $EFSH_SRC_DIR/blog/json.jsonfeed

        efsh_build
        ;;
    fresh)
        rm -f "$EFSH_LASTGEN"
        rm -rf "$EFSH_BUILD_DIR/*"

        efsh_build
        ;;
    init)
        efsh_init
        ;;
    help)
        efsh_help
        ;;
    *)
        efsh_help
        ;;
esac
