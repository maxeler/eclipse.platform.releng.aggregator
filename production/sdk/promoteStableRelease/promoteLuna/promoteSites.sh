#!/usr/bin/env bash

DROP_ID=I20130807-1709
#DROP_ID=I20130605-1939
DL_LABEL=4.4M1
DL_LABEL_EQ=LunaM1
REPO_SITE_SEGMENT=4.4milestones
#REPO_SITE_SEGMENT=4.4
HIDE_SITE=true
#HIDE_SITE=false
export CL_SITE=${PWD}
echo "CL_SITE: ${CL_SITE}"
export DL_TYPE=S
#export DL_TYPE=R
export TRAIN_NAME=Luna
export BUILDMACHINE_BASE_SITE=/shared/eclipse/builds/4I/siteDir/updates/4.3-I-builds
export BUILDMACHINE_BASE_DL=/shared/eclipse/builds/4I/siteDir/eclipse/downloads/drops4

export PROMOTE_IMPL=/shared/eclipse/sdk/promoteStableRelease/promoteImpl
export BUILD_TIMESTAMP=${DROP_ID//[MI-]/}

echo "Promoted: $( date )" > "${CL_SITE}/checklist.txt"
printf "\n\t%s\t\t\t%s\n" "DROP_ID" "$DROP_ID" >> "${CL_SITE}/checklist.txt"
printf "\n\t%s\t\t\t%s" "DL_LABEL" "$DL_LABEL" >> "${CL_SITE}/checklist.txt"
printf "\n\t%s\t\t\t%s" "DL_LABEL_EQ" "$DL_LABEL_EQ" >> "${CL_SITE}/checklist.txt"
printf "\n\t%s\t%s" "REPO_SITE_SEGMENT" "$REPO_SITE_SEGMENT" >> "${CL_SITE}/checklist.txt"
printf "\n\t%s\t\t\t%s\n\n" "HIDE_SITE" "$HIDE_SITE" >> "${CL_SITE}/checklist.txt"

# we do Equinox first, since it has to wait in que until 
# cronjob promotes it
${PROMOTE_IMPL}/promoteDropSiteEq.sh ${DROP_ID} ${DL_LABEL_EQ} ${HIDE_SITE}
rccode=$?
if [[ $rccode != 0 ]]
then
    printf "\n\n\t%s\n\n" "ERROR: promoteDropSiteEq.sh failed. Subsequent promotion cancelled."
    exit $rccode
fi

${PROMOTE_IMPL}/promoteDropSite.sh   ${DROP_ID} ${DL_LABEL} ${HIDE_SITE}
rccode=$?
if [[ $rccode != 0 ]]
then
    printf "\n\n\t%s\n\n" "ERROR: promoteDropSite.sh failed. Subsequent promotion cancelled."
    exit $rccode
fi


${PROMOTE_IMPL}/promoteRepo.sh ${DROP_ID} ${DL_LABEL} ${REPO_SITE_SEGMENT} ${HIDE_SITE}
rccode=$?
if [[ $rccode != 0 ]]
then
    printf "\n\n\t%s\n\n" "ERROR: promoteRepo.sh failed."
    exit $rccode
fi

exit 0
