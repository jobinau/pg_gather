#!/bin/bash
set -eo pipefail

DOCKER_IMAGE=postgres:14   #Take one of the commonly used PG version above 13

if [ -z "${1}" ]; then
    echo "Usage is generate_report.sh path_to_output.txt [path_to_report.html] [keep the docker container y/n]"
    exit 1
fi

GATHER_OUT="${1}"   #First arg is the file to be imported, The "out.txt" file collected from the environment
REPORT_OUT="${2:-$(echo "${GATHER_OUT}" | cut -f 1 -d '.')}.html"  #Second arg : Optional name of the output html file
KEEP_DOCKER="${3:-n}"  #Third arg : Whether the container to be preserved after report generation (y/n)
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
  echo "Container ${CONTAINER_ID} / \"pg_gather\" left around"
  echo "You may connect like: docker exec -it --user postgres pg_gather bash"
fi
#------------------------------------------------------------------------------------------------------------

echo "Finished generating report in ${REPORT_OUT}"
