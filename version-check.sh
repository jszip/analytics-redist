#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$DIR/redist-tools"

if [ "A$2" == "A" ] ; then
    echo "$0 path-to-package.json path-to-pom.xml"
    return 1
fi

JSONVER=$(parse-json "$1")
if [ $? -ne 0 ] ; then
    echo "Could not parse $1"
    # exit with 125 if we want to let git-bisect run continue
    # makes sense if we cannit find the file or parse it
    return 125
fi

POMVER=$(parse-pom "$2")
if [ $? -ne 0 ] ; then
    echo "Could not parse $1"
    # exit with above 128 if we want to stop git-bisect dead in tracks
    # makse sense if we have not got a pom.xml to parse
    return 129
fi

vercomp $POMVER $JSONVER
case $? in
    0)
    echo $JSONVER == $POMVER
    exit 1
    ;;
    1)
    echo $JSONVER '<' $POMVER '(pom.xml is newer)'
    exit 0
    ;;
    2)
    echo $JSONVER '>' $POMVER '(package.json is newer)'
    exit 1
    ;;
esac
