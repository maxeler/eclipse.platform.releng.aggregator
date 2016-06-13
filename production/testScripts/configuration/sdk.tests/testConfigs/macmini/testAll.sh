#!/bin/sh
ulimit -c unlimited

# This file should never exist or be needed for production machine,
# but allows an easy way for a "local user" to provide this file
# somewhere on the search path ($HOME/bin is common),
# and it will be included here, thus can provide "override values"
# to those defined by defaults for production machine.,
# such as for jvm

source localBuildProperties.shsource 2>/dev/null

echo "PWD: $PWD"
jvm=${jvm:-/System/Library/Frameworks/JavaVM.framework/Versions/1.5.0/Commands/java}


# production machine is x86_64, but some local setups may be 32 bit and will need to provide
# this value in localBuildProperties.shsource.
eclipseArch=${eclipseArch:-x86}

# vm.properties is used by default on production machines, but will
# need to override on local setups to specify appropriate vm (usually same as jvm).
# see bug 388269
propertyFile=${propertyFile:-vm.properties}

echo "jvm in testAll: ${jvm}"
echo "extdir in testAll (if any): ${extdir}"
echo "propertyFile in testAll: ${propertyFile}"

#execute command to run tests
/bin/chmod 755 runtestsmac.sh
/bin/mkdir -p results/consolelogs

if [[ -n "${extdir}" ]]
then
  ./runtestsmac.sh -os macosx -ws cocoa -arch $eclipseArch -extdirprop "${extdir}" -vm "${jvm}" -properties ${propertyFile} $* > results/consolelogs/${testedPlatform}_consolelog.txt
else
  ./runtestsmac.sh -os macosx -ws cocoa -arch $eclipseArch -vm "${jvm}" -properties ${propertyFile} $* > results/consolelogs/${testedPlatform}_consolelog.txt
fi
