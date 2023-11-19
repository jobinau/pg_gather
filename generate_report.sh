#!/bin/bash
set -eo pipefail

DOCKER_IMAGE=postgres:14   #Take one of the commonly used PG version above 13

if [ -z "${1}" ]; then
    echo "USEAGE : generate_report.sh path/to/output.tsv [/path/to/report.html] [leave the docker container running? (y/n)]"
    echo "Example : generate_report.sh out.tsv report.html y"
    echo "(Output html file name and flag are optional)"
    exit 1
fi

GATHER_OUT="${1}"   #First arg, the input file to be imported. (The "out.tsv" file)
REPORT_OUT="${2:-${GATHER_OUT%.*}}"  #Second arg (Optional) : if not specified, use the name from the input file   (basename "$filename" | cut -d. -f1)
[[ ! $REPORT_OUT == *.html ]] &&  REPORT_OUT="${REPORT_OUT}.html"   #Append file extension ".html" if not specified already.
KEEP_DOCKER="${3:-n}"  #Third arg (Optional): Whether the container to be preserved after report generation (y/n)
GATHERDIR="$(dirname "$(realpath "$0")")"

if [ ! -f $GATHERDIR/gather_schema.sql ] || [ ! -f $GATHERDIR/gather_report.sql ]; then
  echo "gather_schema.sql and gather_report.sql weren't found; are you running from a cloned repo?"
  exit 1
fi

#--------------- Make sure that a PG container "pg_gather" is running. if required, create one------------------------
if [ "$(docker ps -a -q -f name=pg_gather)" ]; then      #Check wether a docker container "pg_gather" already exists
  if [ "$(docker ps -aq -f status=exited -f name=pg_gather)" ]; then   #Container exists, But it is stopped/exited
    echo "Starting pg_gather container"
    CONTAINER_ID=$(docker start pg_gather)      #Startup the container and get its container id
    sleep 3;
  else
    CONTAINER_ID=$(docker ps -aq -f status=running -f name=pg_gather)   #If container is already running, just get the container id
  fi
fi

if [ -z "${CONTAINER_ID}" ]; then    #If no relevant "pg_gather" container exists
  docker pull "${DOCKER_IMAGE}"
  CONTAINER_ID=$(docker run --name pg_gather -d -e POSTGRES_HOST_AUTH_METHOD=trust ${DOCKER_IMAGE}) #Create a container
  echo "Docker container is ${CONTAINER_ID}; will wait 3 seconds before proceeding"
  sleep 3;
else
  echo "pg_gather container ${CONTAINER_ID} aleady running. Reusing it"   #if container is already existing, just reuse that.
fi
#---------------------Container "pg_gather" is running by this time------------------------------------------

#---------------------Import file to PostgreSQL and generate report------------------------------------------
{ cat $GATHERDIR/gather_schema.sql; cat ${GATHER_OUT}; }  | docker exec -i --user postgres "${CONTAINER_ID}" psql -f - -c "ANALYZE"
cat $GATHERDIR/gather_report.sql | docker exec -i --user postgres "${CONTAINER_ID}" sh -c "psql -X -f -" > "${REPORT_OUT}"
#------------------------------------------------------------------------------------------------------------

#----------------------Decide whether to keep the container or not-------------------------------------------
if [ "n" = "${KEEP_DOCKER}" ]; then
  docker stop "${CONTAINER_ID}"
  docker rm "${CONTAINER_ID}"
  echo "Container ${CONTAINER_ID} deleted"
else
  echo "Leaving the PG container : ${CONTAINER_ID} / \"pg_gather\" in running state"
  echo "You may connect the PG container: docker exec -it --user postgres pg_gather bash"
fi
#------------------------------------------------------------------------------------------------------------

echo "Finished generating report in ${REPORT_OUT}"
