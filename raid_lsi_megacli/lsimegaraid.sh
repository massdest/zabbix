#!/bin/bash 
MEGACLI="sudo /usr/local/bin/megacli"
#
if [[ -n ${1} && -n ${2} && -n ${3} && -z ${4} ]]; then
  ##### DISCOVERY #####
  TYPE="${2}"
  if [[ ${TYPE} == "virtdiskovery" ]]; then
    DRIVES=`${MEGACLI} -LDInfo -LAll -a${3} -NoLog | awk '/Virtual Drive:/ {printf("VirtualDrive%d\n", $3)}'`
    if [[ -n ${DRIVES} ]]; then
      JSON="{ \"data\":["
      for DRIVE in ${DRIVES}; do
        JSON=${JSON}"{ \"{#VIRTNUM}\":\"${DRIVE}\"},"
      done
      JSON=${JSON}"]}"
      echo ${JSON}|sed 's/\,\]\}/\]\}/g'
    fi
  elif [[ ${TYPE} == "physdiskovery" ]]; then
    DRIVES=`${MEGACLI} -PDlist -a${3} -NoLog | awk '/Device Id:/ {printf("DriveSlot%d\n", $3)}'`
    if [[ -n ${DRIVES} ]]; then
      JSON="{ \"data\":["
      for DRIVE in ${DRIVES}; do
        JSON=${JSON}"{ \"{#PHYSNUM}\":\"${DRIVE}\"},"
      done
      JSON=${JSON}"]}"
      echo ${JSON}|sed 's/\,\]\}/\]\}/g'
    fi
  fi
  exit 0
elif [[ -n ${1} && -n ${2} && -n ${3} && -n ${4} ]]; then
  ##### PARAMETERS #####
  HOST="${1}"
  DRIVE="${2}"
  METRIC="${3}"
  FILECACHE="/home/tmp/zabbix.lsimegaraid.cache.${4}"
  TTLCACHE="600"
  TIMENOW=`date '+%s'`
  ##### CACHE #####
  if [ -s "${FILECACHE}" ]; then
    TIMECACHE=`stat -c"%Y" "${FILECACHE}"`
  else
    TIMECACHE=0
  fi
  if [ "$((${TIMENOW} - ${TIMECACHE}))" -gt "${TTLCACHE}" ]; then
    echo "" >> ${FILECACHE} # !!!
    DATACACHE=`${MEGACLI} -PDlist -a${4} -NoLog | awk -F':' '
        function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
        function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
        function trim(s)  { return rtrim(ltrim(s)); }
        /Device Id/              {slotcounter+=1; slot[slotcounter]=trim($2)}
        /Inquiry Data/             {inquiry[slotcounter]=trim($2)}
        /Firmware state/           {state[slotcounter]=trim($2)}
        /Drive Temperature/        {temperature[slotcounter]=trim($2)}
        /S.M.A.R.T/                {smart[slotcounter]=trim($2)}
        /Media Error Count/        {mediaerror[slotcounter]=trim($2)}
        /Other Error Count/        {othererror[slotcounter]=trim($2)}
        /Predictive Failure Count/ {failurecount[slotcounter]=trim($2)}
        END {
          for (i=1; i<=slotcounter; i+=1) {
            printf ( "DriveSlot%d inquiry:%s\n",slot[i], inquiry[i]);
            printf ( "DriveSlot%d state:%s\n", slot[i], state[i]);
            printf ( "DriveSlot%d temperature:%d\n", slot[i], temperature[i]);
            printf ( "DriveSlot%d smart:%s\n", slot[i], smart[i]);
            printf ( "DriveSlot%d mediaerror:%d\n", slot[i], mediaerror[i]);
            printf ( "DriveSlot%d othererror:%d\n", slot[i], othererror[i]);
            printf ( "DriveSlot%d failurecount:%d\n", slot[i], failurecount[i]);
          }
        }';
        ${MEGACLI} -LDInfo -LAll -a${4} -NoLog | awk -F':' '
        function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
        function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
        function trim(s)  { return rtrim(ltrim(s)); }
        /Virtual Drive:/ {drivecounter+=1; slot[drivecounter]=trim($2);}
        /State/          {state[drivecounter]=trim($2)}
        /Bad Blocks/     {badblock[drivecounter]=trim($2)}
        END {
          for (i=1; i<=drivecounter; i+=1) {
            printf ( "VirtualDrive%d state:%s\n", slot[i], state[i]);
            printf ( "VirtualDrive%d badblock:%s\n", slot[i], badblock[i]);
          } 
        }'` || exit 1
    echo "${DATACACHE}" > ${FILECACHE} # !!!
  fi
  #
  cat "${FILECACHE}" | grep -i ${DRIVE} | awk -F':' "/${METRIC}/ {print \$2}" | head -n1
  exit 0
#
else
  exit 0
fi


