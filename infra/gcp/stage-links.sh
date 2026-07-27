#!/bin/bash
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Adapted (Fabric FAST pattern) for this repo's own 10-stage pipeline.

if [ $# -eq 0 ]; then
  echo "Error: no folder or GCS bucket specified. Use -h or --help for usage."
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat <<END
Create commands to initialize stage provider and tfvars files.

Usage with GCS output files bucket:
  stage-links.sh GCS_BUCKET_URI

Usage with local output files folder:
  stage-links.sh FOLDER_PATH
END
  exit 0
fi

if [[ "$1" == "gs://"* ]]; then
  CMD="gcloud storage cp $1"
  CP_CMD=$CMD
elif [ ! -d "$1" ]; then
  echo "folder $1 not found"
  exit 1
else
  CMD="ln -s $1"
  CP_CMD="cp $1"
fi

GLOBALS="tfvars/0-globals.auto.tfvars.json"
PROVIDER_CMD=$CMD
STAGE_NAME=$(basename "$(pwd)")

case $STAGE_NAME in

"0-bootstrap")
  unset GLOBALS
  PROVIDER="providers/0-bootstrap-providers.tf"
  TFVARS=""
  ;;
"1-cloudbuild" | "2-projects" | "3-networking" | "4-gke-nonprod" | "4-gke-production" | \
"5-databases" | "6-vcluster" | "7-flux-bootstrap")
  # Every stage after 0-bootstrap only needs its "plumbing" (project IDs, SA
  # emails, bucket names) from tfvars/0-bootstrap — structural values from a
  # specific prior stage (a VPC self-link, a cluster endpoint) are read via
  # `data "terraform_remote_state"` directly instead of re-published here.
  PROVIDER="providers/${STAGE_NAME}-providers.tf"
  TFVARS="tfvars/0-bootstrap.auto.tfvars.json"
  ;;
*)
  echo "stage '$STAGE_NAME' not found"
  ;;

esac

echo -e "# copy and paste the following commands for '$STAGE_NAME'\n"

echo "$PROVIDER_CMD/$PROVIDER ./"

if [[ ! -z ${GLOBALS+x} ]]; then
  echo "$CMD/$GLOBALS ./"
fi

for f in $TFVARS; do
  echo "$CMD/$f ./"
done
