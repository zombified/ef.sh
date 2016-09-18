#!/bin/bash

VERSION="0.0.2"
# changelog at end of file

# The MIT License (MIT)
#
# Copyright (c) 2014 Joel Kleier
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


# Future things that I'd like TODO:
#   - clean cache of old post md5's that are no longer used
#   - incremental build of tag, archive, interesting things, index, and feed
#   - create feed.xml files for all tags
#   - notice if template(s) change and rebuild they have


# File Structure of Input:
#   - theme/
#       - res/ -- for non-template resources like css, javascript or images
#       - head.html -- for things that go in the <head> of the template
#       - header.html -- for things that go in the header portion of your content
#       - template.html -- the full template for each page on the site
#       - footer.html -- for thigns that go in the footer portion of your content
#   - blog/
#       - 2014-01-foo-bar.md -- the first several lines should be yaml front matter
#   - index.md
#   - interesting-things.md
#   - rss.xml.part -- front matter for the rss.xml document
#   - atom.xml.part -- front matter for the atom.xml document
#   - favicon.ico
#   - favicon.png
#
# File Structure of Output:
#   - blog/
#       - tag/
#           - brewing/
#               - index.html -- lists preview for each entry in tag
#           - index.html -- lists all tags used
#       - archive/index.html
#       - 2014-01-foo-bar/index.html
#   - theme/ -- direct recusive copy of theme/res from input
#   - interesting-things/index.html
#   - index.html -- short intro + recent posts
#   - rss.xml
#   - atom.xml
#   - favicon.ico
#   - favicon.png




# --- CONFIGURATION -----------------------------------------------------------
site_base_url=""
site_fullbase_url="http://joelkleier.com"
post_base_url="${site_base_url}/blog"
post_fullbase_url="${site_fullbase_url}/blog"
project_dir=/home/diode/web/ef
post_dir=${project_dir}/blog
index_file=${project_dir}/index.md
interestingthings_file=${project_dir}/interesting-things.md
rsspart_file=${project_dir}/rss.xml.part
atompart_file=${project_dir}/atom.xml.part

pandoc_theme_dir=${project_dir}/theme
pandoc_theme_res_dir=${project_dir}/theme/res
pandoc_theme_template=${pandoc_theme_dir}/template.html
pandoc_theme_head=${pandoc_theme_dir}/head.html
pandoc_theme_header=${pandoc_theme_dir}/header.html
pandoc_theme_footer=${pandoc_theme_dir}/footer.html
pandoc_opts="--standalone -f markdown -t html5 --include-in-head=${pandoc_theme_head} --include-before-body=${pandoc_theme_header} --include-after-body=${pandoc_theme_footer} --template=${pandoc_theme_template}"
pandoc_opts_fragment="-f markdown -t html5"

cache_dir=${project_dir}/.cache
cache_current=${cache_dir}/current  # md5sum's for files already checked in current run
cache_processed=${cache_dir}/processed  # md5sum's for files that have been preprocessed
cache_tagset=${cache_dir}/tagset  # set of all tags, separated by new lines, used in all posts
cache_tagsort_dir=${cache_dir}/tagsort  # directory to hold files with names of tags that contain post sortdate and md5
cache_tagindex_dir=${cache_dir}/tagindex  # directory holding markdown index files for tags
cache_alltagindex=${cache_dir}/alltagindex.md  # holds lists of posts for tags
cache_sort=${cache_dir}/postsort  # sort dates and md5sums, one pair per row, for each post
cache_recent=${cache_dir}/recent  # holds most recent posts' previews
cache_post_dir=${cache_dir}/posts  # holds cache files for posts
cache_archive=${cache_dir}/archive.md  # holds a list of all posts in blog

output_dir=${project_dir}/output
output_res_dir=${output_dir}/theme
output_post_dir=${output_dir}/blog
output_tag_dir=${output_post_dir}/tag
output_archive_dir=${output_post_dir}/archive
output_interestingthings_dir=${output_dir}/interesting-things
output_rss=${output_dir}/rss.xml
output_atom=${output_dir}/atom.xml


# --- FUNCTIONS ---------------------------------------------------------------

# based on http://www.linuxjournal.com/content/use-date-command-measure-elapsed-time
# Elapsed time.  Usage:
#
#   t=$(timer)
#   ... # do something
#   printf 'Elapsed time: %s\n' $(timer $t)
#      ===> Elapsed time: 0:01:12
#
#####################################################################
# If called with no arguments a new timer is returned.
# If called with arguments the first is used as a timer
# value and the elapsed time is returned in the form HH:MM:SS.
#
function timer()
{
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s%3N')
    else
        local  stime=$1
        etime=$(date '+%s%3N')

        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        dn=$((dt % 1000))
        ds=$(((dt / 1000) % 60))
        dm=$((((dt / 1000) / 60) % 60))
        dh=$(((dt / 1000) / 3600))
        printf '%d:%02d:%02d.%03d' $dh $dm $ds $dn
    fi
}

# based on http://stackoverflow.com/a/21189044
# $1 == file
# $2 == prefix to prepend to variables
function parse_yaml {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    # grab the line number of the second '---' and pass everything in the file
    # up to (and including) that line into the sed/awk commands to parse yaml
    head -n $(grep -rne '---' $1 | sed -n '2 s/:---//p') $1 |
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}


BUILD_T=$(timer)


# --- COMMAND OPTIONS ---------------------------------------------------------
while getopts :hcv opt; do
    case "${opt}" in
        h)
            echo "Usage: $0 [-h] [-c] [-v]"
            exit 0
            ;;
        c)
            CLEARCACHE_T=$(timer)
            echo -n "Clearing cache..."
            rm -rf $cache_dir
            echo "DONE [$(timer ${CLEARCACHE_T})]"
            ;;
        v)
            echo "$(basename $0) version $VERSION"
            exit 0
            ;;
        *)
            ;;
    esac
done


# --- FILESYSTEM SETUP --------------------------------------------------------
FSSETUP_T=$(timer)
echo -n "Preparing filesystem..."

# output
rm -rf "${output_dir}"/*
cp -R "${pandoc_theme_res_dir}" "${output_res_dir}"
mkdir -p "${output_post_dir}"
mkdir -p "${output_archive_dir}"
mkdir -p "${output_interestingthings_dir}"

# cache
mkdir -p $cache_dir
mkdir -p $cache_tagsort_dir
mkdir -p $cache_tagindex_dir
rm -rf $cache_tagindex_dir/*
> $cache_current
> $cache_recent
> $cache_alltagindex
> $cache_archive
touch $cache_processed
touch $cache_tagset
touch $cache_sort

echo "DONE. [$(timer ${FSSETUP_T})]"


# --- PRE-PROCESS POSTS -------------------------------------------------------
PREPROCESS_T=$(timer)
echo "Pre-processing..."
for file in `ls $post_dir/*.md`
do
    POST_t=$(timer)
    POST_filename=$(basename "$file" .md)

    # grab just the md5 hash
    POST_md5=$(md5sum $file | awk '{print substr($0,0,32)}')
    if grep -q "$POST_md5" $cache_processed; then
        echo "...${POST_filename} UNCHANGED. [$(timer ${POST_t})]"
        continue
    fi
    echo $POST_md5 >> $cache_current

    # check to see if the file should be handled at all
    if ! head -n 1 "$file" | grep -Eq "^---$"; then
        echo "...${POST_filename} SKIPPED. [$(timer ${POST_t})]"
        continue
    fi

    # set variables from post metadata
    eval $(parse_yaml "$file" "POST_")

    # create or update variables needed (ones not found in the metadata)
    POST_sortdate=$(date -d "$POST_date" "+%Y%m%d")
    POST_rssdate=$(date -d "$POST_date" "+%a, %d %b %Y 00:00:00 %Z")
    POST_displaydate=$(date -d "$POST_date" "+%Y-%m-%d")
    POST_tags=$(echo $POST_tags | sed 's/^\[//; s/\]$//;')
    POST_url="${post_base_url}/${POST_filename}/"
    POST_fullurl="${post_fullbase_url}/${POST_filename}/"

    # create cache directory for rendered post data
    POST_dir="${cache_post_dir}/${POST_md5}"
    mkdir -p $POST_dir

    # generate preview (html) and list snippet (markdown)
    POST_listsnippet="  * [${POST_title}](${POST_url}) ${POST_displaydate}"
    POST_preview="<article class='postpreview'><header><h1><a href='${POST_url}'>${POST_title}</a></h1></header><time class='date' datetime='${POST_rssdate}'>${POST_displaydate}</time><p>${POST_description}</p></article>"
    echo "${POST_listsnippet}" > $POST_dir/listsnippet
    echo ${POST_preview} > $POST_dir/preview

    # generate html page for the post
    #   the grep and sed statement get the number of lines used for metadata in the
    #   post, and the tail statement only grabs the contents of the file after the
    #   end of the metadata
    mkdir -p "${POST_dir}/output/${POST_filename}/"
    tail -n +$((2+$(grep -rne '---' "$file" | sed -n '2 s/:---//p'))) "$file" |
    pandoc $pandoc_opts \
        --output="${POST_dir}/output/${POST_filename}/index.html" \
        --variable=title:"${POST_title}" \
        --variable=fulldate:"${POST_rssdate}" \
        --variable=displaydate:"${POST_displaydate}" \
        --variable=tags:"${POST_tags}"
    # generate a html snippet for just the post text
    tail -n +$((2+$(grep -rne '---' "$file" | sed -n '2 s/:---//p'))) "$file" |
    pandoc $pandoc_opts_fragment \
        --output="${POST_dir}/htmlfragment" \
        --variable=title:"${POST_title}" \
        --variable=fulldate:"${POST_rssdate}" \
        --variable=displaydate:"${POST_displaydate}" \
        --variable=tags:"${POST_tags}"

    # generate rss feed part (xml)
    POST_html=$(cat "${POST_dir}/htmlfragment")
    POST_rss="<item><title><![CDATA[${POST_title}]]></title><link>${POST_fullurl}</link><description><![CDATA[${POST_html}]]></description><pubDate>${POST_rssdate}</pubDate><guid isPermaLink='false'>${POST_fullurl}</guid></item>"
    echo "${POST_rss}" > "${POST_dir}/rss"
    POST_atom="<entry><title><![CDATA[${POST_title}]]></title><link>${POST_fullurl}</link><summary><![CDATA[${POST_html}]]></summary><updated>${POST_rssdate}</updated><id>${POST_md5}</id><author><name>Joel Kleier</name><email>joel@kleier.us</email></author></entry>"
    echo "${POST_atom}" > "${POST_dir}/atom"

    # process tags
    oIFS="$IFS"
    IFS=', ' read -a TAGS <<< "$POST_tags"
    for element in "${TAGS[@]}"
    do
        # add to tag set, if it doesn't exist there yet
        if ! grep -q "$element" "$cache_tagset"; then
            echo "$element" >> $cache_tagset
        fi

        # create cached list snippet for post to tag's list
        echo $POST_listsnippet > "${POST_dir}/tag_${element}"

        # add post to tag's post list
        touch "${cache_tagsort_dir}/${element}"
        echo "${POST_sortdate}%%${POST_md5}" >> "${cache_tagsort_dir}/${element}"
    done
    IFS=$oIFS

    # add post to all-post list
    echo "${POST_sortdate}%%${POST_md5}" >> "${cache_sort}"

    # mark it as having been pre-processed
    echo $POST_md5 >> $cache_processed

    echo "...${POST_filename} DONE [$(timer ${POST_t})]"
done
echo "Pre-processing DONE. [$(timer ${PREPROCESS_T})]"


# create index page
IDXGEN_T=$(timer)
echo -n "Generating site index..."

## sort the file (most recent first), select the top 5, and then print out just the md5
for postmd5 in $(sort -nr "${cache_sort}" | sed -n '1,5 p' | awk 'BEGIN{FS="%%"};{print $2 "\n"}')
do
    cat "${cache_post_dir}/${postmd5}/preview" >> $cache_recent
done
## combine the index.md and most recent into a single file, then convert it all
## as a markdown document into it's output
pandoc $pandoc_opts \
    --output="$output_dir/index.html" \
    --variable=title:"" \
    $index_file $cache_recent

echo "DONE. [$(timer $IDXGEN_T)]"


# process all posts
POSTGEN_T=$(timer)
echo -n "Copying posts to output..."

for postmd5 in $(sort -nr "${cache_sort}" | awk 'BEGIN{FS="%%"};{print $2 "\n"}')
do
    cp -R "${cache_post_dir}/${postmd5}/output/"* "${output_post_dir}"
done

echo "DONE. [$(timer $POSTGEN_T)]"


# create tag indexes
TAGIDXGEN_T=$(timer)
echo "Creating tag indexes..."

for file in `ls ${cache_tagsort_dir}`
do
    TAG=$(basename "$file")

    TAGIDX_T=$(timer)
    echo -n "...${TAG}"

    # clear existing cache files
    > "${cache_tagindex_dir}/${TAG}.md"

    # add a heading for the tag
    printf "\n\n## ${TAG}\n" >> "${cache_alltagindex}"

    # create markdown file listing all posts
    for postmd5 in $(sort -nr "${cache_tagsort_dir}/${TAG}" | awk 'BEGIN{FS="%%"};{print $2 "\n"}')
    do
        cat "${cache_post_dir}/${postmd5}/listsnippet" >> "${cache_tagindex_dir}/${TAG}.md"
        cat "${cache_post_dir}/${postmd5}/listsnippet" >> "${cache_alltagindex}"
    done

    # make sure the output directory for the tag exists and is empty
    mkdir -p "${output_tag_dir}/${TAG}"
    rm -rf "${output_tag_dir}/${TAG}/"*

    # generate the index.html file for the tag
    pandoc $pandoc_opts \
        --output="${output_tag_dir}/${TAG}/index.html" \
        --variable=title:"${TAG}" \
        "${cache_tagindex_dir}/${TAG}.md"

    echo " DONE. [$(timer $TAGIDX_T)]"
done

# generate the all-tag index
ALLTAGIDX_T=$(timer)
echo -n "Creating all-tag index..."

pandoc $pandoc_opts \
    --output="${output_tag_dir}/index.html" \
    --variable=title:"Tags" \
    "${cache_alltagindex}"

echo "DONE. [$(timer $ALLTAGIDX_T)]"

echo "DONE creating tag indexes. [$(timer $TAGIDXGEN_T)]"


# generate archive page (list of all posts)
ARCHIVE_T=$(timer)
echo -n "Creating archive index..."

for postmd5 in $(sort -nr "${cache_sort}" | awk 'BEGIN{FS="%%"};{print $2 "\n"}')
do
    cat "${cache_post_dir}/${postmd5}/listsnippet" >> "${cache_archive}"
done

pandoc $pandoc_opts \
    --output="${output_archive_dir}/index.html" \
    --variable=title:"Archive" \
    "${cache_archive}"

echo "DONE. [$(timer $ARCHIVE_T)]"


# generate interesting-things page
INTTHINGS_T=$(timer)
echo -n "Creating interesting things index..."

pandoc $pandoc_opts \
    --output="${output_interestingthings_dir}/index.html" \
    --variable=title:"Interesting Things" \
    "${interestingthings_file}"

echo "DONE. [$(timer $INTTHINGS_T)]"


# generate rss/atom feeds
FEED_T=$(timer)
echo -n "Creating site rss and atom feed..."

## copy some static parts
cp "$rsspart_file" "$output_rss"
cp "$atompart_file" "$output_atom"

## put pub date and other needed date related meta tags
printf "<lastBuildDate>$(date "+%a, %d %b %Y %H:%M:%S %Z")</lastBuildDate>" >> "$output_rss"
printf "<pubDate>$(date "+%a, %d %b %Y %H:%M:%S %Z")</pubDate>" >> "$output_rss"
printf "<updated>$(date "+%a, %d %b %Y %H:%M:%S %Z")</updated>" >> "$output_atom"

## put most recent 10 items into feed
for postmd5 in $(sort -nr "${cache_sort}" | sed -n '1,10 p' | awk 'BEGIN{FS="%%"};{print $2 "\n"}')
do
    cat "${cache_post_dir}/${postmd5}/rss" >> "${output_rss}"
    cat "${cache_post_dir}/${postmd5}/atom" >> "${output_atom}"
done

## close feed up
printf "</channel></rss>" >> "${output_rss}"
printf "</feed>" >> "${output_atom}"

echo "DONE. [$(timer ${FEED_T})]"


# copy misc files to output
CPY_T=$(timer)
echo -n "Copying remaining files to output..."

cp "${project_dir}/favicon.ico" "${output_dir}"
cp "${project_dir}/favicon.png" "${output_dir}"

echo "DONE. [$(timer ${CPY_T})]"


echo "Build Completed. [$(timer ${BUILD_T})]"

# CHANGES
# =======
#
# 0.0.2
# -----
# - added rss links to head
# - adjusted some of the meta tags in head
# - added favicon to template
#
# 0.0.1
# -----
# Initial release
#
