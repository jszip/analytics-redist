#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$DIR/redist-tools"
source "$DIR/redist-config"

if [ ! -d "$DIR/target/upstream" ] ; then
    rm -rf "$DIR/target/upstream"
    mkdir -p "$DIR/target/upstream"
    git clone $UPSTREAM_GIT_URL "$DIR/target/upstream"
else
	cd "$DIR/target/upstream"
	git fetch origin
	git checkout master
    git reset --hard origin/master
    cd -
fi

JSONVER=$(parse-json "$DIR/target/upstream/package.json")
if [ $? -ne 0 ] ; then
    echo "Could not parse $DIR/target/upstream/package.json"
    exit 255
fi

POMVER=$(parse-pom "$DIR/pom.xml")
if [ $? -ne 0 ] ; then
    echo "Could not parse $DIR/pom.xml"
    exit 255
fi

vercomp $POMVER $JSONVER
if [ $? -eq 1 ] ; then
    echo "Waiting for a newer release"
else
    echo "Searching for update..."
    GOOD_REV=$(xpath "$DIR/pom.xml" "/project/properties/$POM_PROPERTY/text()")
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
    sed -e "s:<version>$EXACT</version>:<version>$REPL-SNAPSHOT</version>:;s:<$POM_PROPERTY>$GOOD_REV</$POM_PROPERTY>:<$POM_PROPERTY>$BAD_REV</$POM_PROPERTY>:" < "$DIR/pom.xml" > "$DIR/pom.xml.new"
    mvn clean verify -f "$DIR/pom.xml.new"
    if [ $? -eq 0 ] ; then
    	mv -f "$DIR/pom.xml.new" "$DIR/pom.xml"
    fi
fi
