#!/usr/bin/env bash

# version in R4_5_maintenance

# Utility script to get "ebuilder"
printf "\n\tDEBUG: %s\n" "executing ${0}"
printf "\t\t\t%s\n" "As called from ${FUNCNAME[1]}, called from line number ${BASH_LINENO[0]} in ${BASH_SOURCE[1]}."

SCRIPT_PATH=${SCRIPT_PATH:-$(pwd)}
printf "\n\tINFO: %s\n" "SCRIPT_PATH: $SCRIPT_PATH"
source $SCRIPT_PATH/build-functions.shsource

BUILD_DIR=$1
EBUILDER_HASH=$2


if [[ -z "${BUILD_DIR}" ]]
then
  printf "\n\tWARNING: %s\n" "BUILD_DIR not defined, assuming $BUILD_DIR"
  BUILD_DIR=${PWD}
else
  # normally will exist by now, but if not, we'll create it.
  if [[ ! -d "${BUILD_DIR}" ]]
  then
    printf "\n\tWARNING: %s\n" "BUILD_DIR did not exist when expected. Creating $BUILD_DIR"
    mkdir -p $BUILD_DIR
  fi
fi

if [[ -z "${EBUILDER_HASH}" ]]
then
  echo "EBUILDER HASH, BRANCH, or TAG was not supplied, assuming 'master'"
  EBUILDER_HASH=master
fi

EBUILDER=eclipse.platform.releng.aggregator
# derived values
gitCache=$( fn-git-cache "$BUILD_ROOT")
aggDir=$( fn-git-dir "$gitCache" "$AGGREGATOR_REPO" )

RC=0

# don't clone, if already exists.
# TODO: could do more error checking, if hash is what we expect, 
# if the zip file already exists. But 99.99% sure all is fine, 
# if this directory already exists. Might be an issue in resuming 
# a failed build, without cleaning everything first? (Which we currently 
# do not do.) Even then, might be best to delete everything, including 
# the zip, and re-clone. It is, after all, a detached head.
if [[ ! -d ${BUILD_DIR}/${EBUILDER} ]]
then
  # Not sure 'REPO_AND_ACCESS' is defined in all possible scenarios, so we'll provide a default.
  # It is in main scenarios, but not sure about things like "re-running unit tests at a later time".
  # If directory doesn't exist yet, create it first, so we can assign proper access
  # permissions for later "clean up" routines.
  mkdir -p "${BUILD_DIR}/${EBUILDER}"
  chmod -c g+ws "${BUILD_DIR}/${EBUILDER}"
  # note the use of "reference" ... we typically only need a little bit of
  # new stuff, that the gitCache version doesn't have already, if any.

  echo "Doing git clone using:  --reference  \${aggDir} \${AGGREGATOR_REPO} \${BUILD_DIR}/\${EBUILDER}"
  echo "which evaluates to git clone  --reference  ${aggDir} ${AGGREGATOR_REPO} ${BUILD_DIR}/${EBUILDER}"
  git clone --reference  ${aggDir} ${AGGREGATOR_REPO} ${BUILD_DIR}/${EBUILDER}
  RC=$?
  if [[ $RC != 0 ]]
  then
    echo "[ERROR] Cloning EBUILDER returned non zero return code: $RC"
    exit $RC
  fi

  echo "INFO: ebuilder directory cloned."
  echo "INFO:    Location: ${BUILD_DIR}/${EBUILDER}"
  echo "INFO:    checking out specific HASH (which will make it detached)."
  pushd ${BUILD_DIR}/${EBUILDER}
  git checkout $EBUILDER_HASH
  RC=$?
  if [[ $RC != 0 ]]
  then
    echo "[ERROR] Checking out EBUILDER for $EBUILDER_HASH returned non zero return code: $RC"
    exit $RC
  fi
  popd

  # prepare a (small) zip, for easy retrieval of "production" files, during unit tests on Hudson.
  # This basic function used to be provided by CGit, but was turned off for "snapshots" of commits,
  # and was a bit overkill for those doing their own "remote" test builds (or tests).
  # This small zip is stored, unadvertised, on download site, and retrieved as part of the
  # Hudson test "bootstrap". The "production" directory in general, though, is also
  # used during the build itself.
  # (hard to know "where" we are at ... so we'll make sure.
  printf "\n\tDEBUG: %s\n" "About to create EBuilder zip: ${EBUILDER}-${EBUILDER_HASH}.zip"
  pushd ${buildDirectory}
  zip -r "${buildDirectory}/${EBUILDER}-${EBUILDER_HASH}.zip"  "${EBUILDER}/production/testScripts"
  popd
  exit $RC
fi
