#!/bin/bash
set -eo pipefail

DOCKER_IMAGE=postgres:14

if [ -z "${1}" ]; then
    echo "Usage is generate_report.sh path_to_output.txt [path_to_report.html] [keep the docker container y/n]"
    exit 1
fi

GATHER_OUT="${1}"
REPORT_OUT="${2:-$(echo "${GATHER_OUT}" | cut -f 1 -d '.')}.html"
KEEP_DOCKER="${3:-n}"
GATHERDIR="$(dirname "$(realpath "$0")")"

if [ ! -f $GATHERDIR/gather_schema.sql ] || [ ! -f $GATHERDIR/gather_report.sql ]; then
  echo "gather_schema.sql and gather_report.sql weren't found; are you running from a cloned repo?"
  exit 1
fi

docker pull "${DOCKER_IMAGE}"
CONTAINER_ID=$(docker run -d -e POSTGRES_HOST_AUTH_METHOD=trust ${DOCKER_IMAGE})
echo "Docker container is ${CONTAINER_ID}; will wait 3 seconds before proceeding"
sleep 3;

{ cat $GATHERDIR/gather_schema.sql; cat ${GATHER_OUT}; }  | docker exec -i --user postgres "${CONTAINER_ID}" psql -f - -c "ANALYZE"
cat $GATHERDIR/gather_report.sql | docker exec -i --user postgres "${CONTAINER_ID}" sh -c "psql -X -f -" > "${REPORT_OUT}"

docker stop "${CONTAINER_ID}"
if [ "n" = "${KEEP_DOCKER}" ]; then
  docker rm "${CONTAINER_ID}"
  echo "Container ${CONTAINER_ID} deleted"
else
  echo "Container ${CONTAINER_ID} left around"
fi

echo "Finished generating report in ${REPORT_OUT}"
