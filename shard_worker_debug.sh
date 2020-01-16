#!/bin/bash
#Description: retrieve debugging information from a worker node via SSH
#             connection control plane manager pod via kubectl

### Runtime config
PR=$1
WORKER=$2
SHARD="test-shard-pr-$PR"
LOGPREFIX="azure_pr_$PR"
SSH_OPTS="-o StrictHostKeychecking=no -o ConnectTimeout=10 -o PreferredAuthentications=Pubkey"
SSH_OPTS="-o StrictHostKeychecking=no -o ConnectTimeout=10"

### Helper Functions
function usage {
  echo
  echo USAGE:
  echo "    $0 {PR_NUMBER} [WORKER_IP_ADDR]"
  exit 1
}

function header {
  echo 
  echo "**** $* ****"
  echo
}

function item {
  echo "** $*"
}


### Main script body
( [ $# -lt 1 ] || [ $# -gt 2 ] ) && usage

item SHARD being accessed: $SHARD
item Local logs dumped to $LOGPREFIX

# Test kubecfg auth working
header Listing PODS
kubecfg get pods --context dev-azure-westus --namespace $SHARD | tee ${LOGPREFIX}.pod_list
if [ $? -ne 0 ] ; then
  echo 
  echo "*** Please run:  bin/get-kube-access dev  before using this script for auth. ***"
  exit 2
fi 

if [ $# -lt 2 ]; then
  item Please specify worker IP address to allow collection of worker information
  exit 0
fi

# Gather shard info and compile base kubectl command
MGR=`kubecfg get pods --context dev-azure-westus --namespace $SHARD 2>/dev/null | grep cons-manager | awk -F ' ' '{print $1}'`
KEY=$(kubectl --context dev-azure-westus --namespace $SHARD exec $MGR -- find ./keys/workerPrivateKeysByEnv/ 2>/dev/null | grep workerenv | head -1)
KUBECTL="kubectl --context dev-azure-westus --namespace $SHARD exec -it $MGR -- ssh -i $KEY $SSH_OPTS ubuntu@$WORKER"

echo $KUBECTL

# Confirm access to worker via kubectl command; if broken, may need to debug $KEY (or set manually)
header Checking ssh connectivity to worker
kubectl --context dev-azure-westus --namespace $SHARD exec $MGR -- ssh -v -i $KEY $SSH_OPTS ubuntu@$WORKER /bin/ls
if [ $? -ne 0 ] ; then 
  item FAILURE connecting to $WORKER using key $KEY -- aborting
  exit 3
else
  item SUCCESS
fi

# Grab logs from worker
header "Pulling logs"  
for LOG in syslog bootstrap cloud-init.log cloud-init-output.log ; do 
  item /var/log/$LOG
  $KUBECTL "sudo cat /var/log/$LOG" > ${LOGPREFIX}.${LOG}
done

item "/home/ubuntu/databricks/node/logs/update_worker_output*.log > ${LOGPREFIX}.node.logs"
$KUBECTL cat  /home/ubuntu/databricks/node/logs/update_worker_output*.log > ${LOGPREFIX}.node.logs

# List directories of interest
header Listing directories
for DPATH in /home/ubuntu/databricks/ /home/ubuntu/databricks/node/ /home/ubuntu/databricks/node/logs/  /dev/disk/cloud/ /var/log ; do 
  item $DPATH
  $KUBECTL “/bin/ls -asl $DPATH”
done

# Other debugging information
header Additional diagnostics
item cc_mounts.py output
grep cc_mounts ${LOGPREFIX}.cloud-init.log

item Error and failure messages in /var/log/*
$KUBECTL “sudo grep -iR -e fail -e error /var/log/*” | tee ${LOGPREFIX}.errors

item Sysctl settings
$KUBECTL "sysctl -a" > ${LOGPREFIX}.sysctl_values
grep ipv4.*forwarding ${LOGPREFIX}.sysctl_values

item IPTables rules
$KUBECTL "sudo iptables -L -n" | tee ${LOGPREFIX}.iptables_rules
