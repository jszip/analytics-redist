#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

if [ ! -d "$DIR/target/upstream" ] ; then
    rm -rf "$DIR/target/upstream"
    mkdir -p "$DIR/target/upstream"
    git clone git://github.com/segmentio/analytics.js.git "$DIR/target/upstream"
else
	cd "$DIR/target/upstream"
	git fetch origin
	git checkout master
    git reset --hard origin/master
    cd -
fi

"$DIR/version-check.sh" "$DIR/target/upstream/package.json" "$DIR/pom.xml"

if [ $? -eq 1 ] ; then
    echo "Searching for update..."
    GOOD_REV=$(xpath "$DIR/pom.xml" '/project/properties/analytics-branch/text()')
    if [ $? -ne 0 ] ; then
    	echo "Cannot parse pom.xml, check the scripts are still valid"
    	exit 255
    fi
    cd "$DIR/target/upstream"
    git bisect start origin/master $GOOD_REV
    BAD_REV=$(git bisect run "$DIR/version-check.sh" "$DIR/target/upstream/package.json" "$DIR/pom.xml" | sed -ne "s/ is the first bad commit//p")
    if [ "A$BAD_REV" == "A" ] ; then
    	echo "Could not find revision, check the scripts are still valid"
        cd -
    	exit 255
    fi
    git checkout $BAD_REV
    cd -
    EXACT=$(xpath "$DIR/pom.xml" '/project/version/text()' 2>/dev/null)
    REPL=$(parse-json "$DIR/target/upstream/package.json")
    sed -e "s:<version>$EXACT</version>:<version>$REPL-SNAPSHOT</version>:;s:<analytics-branch>$GOOD_REV</analytics-branch>:<analytics-branch>$BAD_REV</analytics-branch>:" < "$DIR/pom.xml" > "$DIR/pom.xml.new"
    mvn clean verify -f "$DIR/pom.xml.new"
    if [ $? -eq 0 ] ; then
    	mv -f "$DIR/pom.xml.new" "$DIR/pom.xml"
    fi
fi