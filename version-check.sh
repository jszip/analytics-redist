#!/bin/bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

parse-pom() {
    if [ ! -f "$1" ] ; then
        echo "$1 is not a file" 1>&2
        return 1
    fi
    xpath "$1" '/project/version/text()' 2>/dev/null | sed -e 's/-SNAPSHOT//' 
    if [ ${PIPESTATUS[0]} -ne 0 ] ; then
        return 1
    fi
}

parse-json() {
    if [ ! -f "$1" ] ; then
        echo "$1 is not a file" 1>&2
        return 1
    fi

    cat "$1" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["version"]' 
}

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
    exit 0
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