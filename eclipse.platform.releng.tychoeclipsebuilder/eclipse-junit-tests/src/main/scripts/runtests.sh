#!/usr/bin/env bash

# This file should never exist or be needed for production machine,
# but allows an easy way for a "local user" to provide this file
# somewhere on the search path ($HOME/bin is common),
# and it will be included here, thus can provide "override values"
# to those defined by defaults for production machine.,
# such as for vmcmd

source localTestsProperties.shsource


# by default, use the java executable on the path for outer and test jvm
#vmcmd=${vmcmd:-/shared/common/jdk-1.6.x86_64/jre/bin/java}
vmcmd=java

echo "vmcmd: $vmcmd"

# jvm should already be defined, by now, in production tests
# export jvm=${jvm:-/shared/common/jdk1.8.0_x64/jre/bin/java}
# but if not, we use a simple 'java'.
if [[ -z "${jvm}" ]]
then
  echo "WARNING: jvm was not defined, so using simple 'java'."
  export jvm=$(which java)
fi

if [[ -z "${jvm}" || ! -x ${jvm} ]]
then
  echo "ERROR: No JVM define, or the defined one was found to not be executable"
  exit 1
fi
echo "jvm: $jvm"

# On production, WORKSPACE is the 'hudson' workspace.
# But, if running standalone, we'll assume "up two" from current directoy
WORKSPACE=${WORKSPACE:-"../../.."};

stableEclipseSDK=${stableEclipseSDK:-eclipse-SDK-4.5.1-linux-gtk-x86_64.tar.gz}
stableEclipseInstallLocation=${stableEclipseInstallLocation:-${WORKSPACE}/org.eclipse.releng.basebuilder}

# Note: test.xml will "reinstall" fresh install of what we are testing,
# but we do need an install for initial launcher, and, later, need one for a
# stable version of p2 director. For both purposes, we
# we should use "old and stable" version,
# which needs to be installed in ${stableEclipseInstallLocation}.
# Note: for production tests, we use ${WORKSPACE}/org.eclipse.releng.basebuilder,
# for historical reasons. The "true" (old) basebuilder does not have an 'eclipse' directory;
# plugins is directly under org.eclipse.releng.basebuilder.
if [[ ! -r ${stableEclipseInstallLocation} || ! -r "${stableEclipseInstallLocation}/eclipse" ]]
then
  mkdir -p ${stableEclipseInstallLocation}
  tar -xf ${stableEclipseSDK} -C ${stableEclipseInstallLocation}
fi

launcher=$(find ${stableEclipseInstallLocation} -name "org.eclipse.equinox.launcher_*.jar" )
if [ -z "${launcher}" ]
then
  echo "ERROR: launcher not found in ${stableEclipseInstallLocation}"
  exit 1
fi
echo "launcher: $launcher"

# define, but null out variables we expect on the command line
# operating system, windowing system and architecture variables
os=
ws=
arch=

# list of tests (targets) to execute in test.xml
tests=

# default value to determine if eclipse should be reinstalled between running of tests
installmode="clean"

# name of a property file to pass to Ant
properties=

# ext dir customization. Be sure "blank", if not defined explicitly on command line
extdirproperty=

# message printed to console
usage="usage: $0 -os <osType> -ws <windowingSystemType> -arch <architecture> [-noclean] [<test target>][-properties <path>]"


# proces command line arguments
while [ $# -gt 0 ]
do
  case "${1}" in
    -dir)
      dir="${2}"; shift;;
    -os)
      os="${2}"; shift;;
    -ws)
      ws="${2}"; shift;;
    -arch)
      arch="${2}"; shift;;
    -noclean)
      installmode="noclean";;
    -properties)
      properties="-propertyfile ${2}";shift;;
    -extdirprop)
      extdirproperty="-Djava.ext.dirs=${2}";shift;;
    -vm)
      vmcmd="${2}"; shift;;
    *)
      tests=$tests\ ${1};;
  esac
  shift
done

echo "Specified test targets (if any): ${tests}"

echo "Specified ext dir (if any): ${extdirproperty}"

# for *nix systems, os, ws and arch values must be specified
if [ "x$os" = "x" ]
then
  echo >&2 "$usage"
  exit 1
fi

if [ "x$ws" = "x" ]
then
  echo >&2 "$usage"
  exit 1
fi

if [ "x$arch" = "x" ]
then
  echo >&2 "$usage"
  exit 1
fi

#necessary when invoking this script through rsh
cd $dir

if [ ! -r eclipse ]
then
  tar -xzf eclipse-SDK-*.tar.gz
  # note, the file pattern to match, must not start with */plugins because there is no leading '/' in the zip file, since they are repos.
  unzip -qq -o -C eclipse-junit-tests-*.zip plugins/org.eclipse.test* -d eclipse/dropins/
fi

# run tests
launcher=`ls eclipse/plugins/org.eclipse.equinox.launcher_*.jar`

echo " = = = Start list environment variables in effect = = = ="
env
echo " = = = End list environment variables in effect = = = ="

# make sure there is a window manager running. See bug 379026
# we should not have to, but may be a quirk/bug of hudson setup
# assuming metacity attaches to "current" display by default (which should have
# already been set by Hudson). We echo its value here just for extra reference/cross-checks.

echo "Check if any window managers are running (xfwm|twm|metacity|beryl|fluxbox|compiz|kwin|openbox|icewm):"
wmpss=$(ps -ef | egrep -i "xfwm|twm|metacity|beryl|fluxbox|compiz|kwin|openbox|icewm" | grep -v egrep)
echo "Window Manager processes: $wmpss"
echo

if [[ -z $wmpss ]]
then
  echo "No window managers processes found running, so will start metacity"
  metacity --replace --sm-disable  &
  METACITYPID=$!
  echo $METACITYPID > epmetacity.pid
else
  echo "Existing window manager found running, so did not force start of metacity"
fi

echo

# list out metacity processes so overtime we can see if they accumulate, or if killed automatically
# when our process exits. If not automatic, should use epmetacity.pid to kill it when we are done.
echo "Current metacity processes running (check for accumulation):"
ps -ef | grep "metacity" | grep -v grep
echo

echo "Triple check if any window managers are running (at least metacity should be!):"
wmpss=$(ps -ef | egrep -i "xfwm|twm|metacity|beryl|fluxbox|compiz|kwin|openbox|icewm" | grep -v egrep)
echo "Window Manager processes: $wmpss"
echo
echo "extdirprop in runtest: ${extdirprop}"
echo "extdirproperty in runtest: ${extdirproperty}"

# -Dtimeout=300000 "${ANT_OPTS}"
if [[ ! -z "${extdirproperty}" ]]
then
  $vmcmd "${extdirproperty}" -Dosgi.os=$os -Dosgi.ws=$ws -Dosgi.arch=$arch -jar $launcher -data workspace -application org.eclipse.ant.core.antRunner -file ${PWD}/test.xml $tests -Dws=$ws -Dos=$os -Darch=$arch -D$installmode=true $properties -logger org.apache.tools.ant.DefaultLogger
else
  $vmcmd -Dosgi.os=$os -Dosgi.ws=$ws -Dosgi.arch=$arch  -jar $launcher -data workspace -application org.eclipse.ant.core.antRunner -file ${PWD}/test.xml $tests -Dws=$ws -Dos=$os -Darch=$arch -D$installmode=true $properties -logger org.apache.tools.ant.DefaultLogger
fi
