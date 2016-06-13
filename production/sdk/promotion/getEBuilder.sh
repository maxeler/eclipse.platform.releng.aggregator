#!/usr/bin/env bash

# Utility script to "bootstrap" Hudson Eclipse Platform Unit tests, to get the
# basic files needed to get all the other required files and start the test framework.

source localBuildProperties.shsource 2>/dev/null

EBUILDER_HASH=$1
WORKSPACE=$2

if [[ -z "${WORKSPACE}" ]]
then
  echo "WORKSPACE not supplied, will assume current directory"
  WORKSPACE=${PWD}
else
  if [[ ! -d "${WORKSPACE}" ]]
  then
    echo "ERROR: WORKSPACE did not exist."
    exit 1
  fi
fi

if [[ -z "${EBUILDER_HASH}" ]]
then
  echo "EBUILDER HASH, BRANCH, or TAG was not supplied, assuming 'master'"
  EBUILDER_HASH=master
fi

  EBUILDER=eclipse.platform.releng.aggregator
  TARGETNAME=eclipse.platform.releng.aggregator
  ESCRIPT_LOC=${EBUILDER}/production/testScripts

# don't re-fetch, if already exists.
# TODO: May need to provide a "force" parameter to use when testing?
if [[ ! -d ${WORKSPACE}/${TARGETNAME} ]]
then
  # remove just in case left from previous failed run
  # if they exist
  if [[ -f ebuilder.zip ]]
  then
    rm ebuilder.zip
  fi
  if [[ -d tempebuilder ]]
  then
    rm -fr tempebuilder
  fi

  if [[ -z "${GIT_HOST}" ]]
  then
    GIT_HOST=git.eclipse.org
  fi

  wget -O ebuilder.zip --no-verbose http://${GIT_HOST}/c/platform/${EBUILDER}.git/snapshot/${EBUILDER}-${EBUILDER_HASH}.zip 2>&1
  unzip -q ebuilder.zip -d tempebuilder
  mkdir -p ${WORKSPACE}/${TARGETNAME}
  rsync --recursive "tempebuilder/${EBUILDER}-${EBUILDER_HASH}/" "${WORKSPACE}/${TARGETNAME}/"
  rccode=$?
  if [[ $rccode != 0 ]]
  then
    echo "ERROR: rsync did not complete normally.rccode: $rccode"
    exit $rccode
  fi
else
  echo "INFO: ebuilder directory found to exist. Not re-fetching."
  echo "INFO:    ${WORKSPACE}/${TARGETNAME}"
fi

# remove on clean exit, if they exist
if [[ -f ebuilder.zip ]]
then
  rm ebuilder.zip
fi
if [[ -d tempebuilder ]]
then
  rm -fr tempebuilder
fi
exit 0

