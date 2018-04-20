#!/usr/bin/env bash
usage() {
  echo "$ ./install.sh [options]"
  echo "options:"
  echo "-s,       for real-world deployment on a server"
  echo "-l,       for trail purpose on a local VM"
  exit 1;
}

while getopts ":hsl" opt; do
  case $opt in
    h)
      usage
      ;;
    s)
      echo "server" >&2
      OPTION="server"
      ;;
    l)
      echo "local" >&2
      OPTION="local"
      ;;
    \?)
      echo "Invalid Option"
      usage
      ;;
  esac
done

if [ $# -eq 0 ]
  then
    usage
fi


#####################################
## Initialization & Helper Functions
#####################################
shopt -s extglob
set -e
set -o errtrace
set -o errexit

# Email and signup link are Base64-coded to prevent scraping

if [[ "$OSTYPE" == "darwin"* ]]; then
OUR_EMAIL=`echo -n 'YXV0b2xhYi1kZXZAYW5kcmV3LmNtdS5lZHU=' | base64 -D`
LIST_SIGNUP=`echo -n 'aHR0cDovL2VlcHVybC5jb20vYlRUT2lU' | base64 -D`
else
OUR_EMAIL=`echo -n 'YXV0b2xhYi1kZXZAYW5kcmV3LmNtdS5lZHU=' | base64 -d`
LIST_SIGNUP=`echo -n 'aHR0cDovL2VlcHVybC5jb20vYlRUT2lU' | base64 -d`
fi
SCRIPT_PATH="${BASH_SOURCE[0]}";

# Colorful output
_red=`tput setaf 1`
_green=`tput setaf 2`
_orange=`tput setaf 3`
_blue=`tput setaf 4`
_purple=`tput setaf 5`
_cyan=`tput setaf 6`
_white=`tput setaf 6`
_reset=`tput sgr0`


# Log file
LOG_FILE=`mktemp`

# Global helpers
log()  { printf "${_green}%b${_reset}\n" "$*"; printf "\n%b\n" "$*" >> $LOG_FILE; }
logstdout() { printf "${_green}%b${_reset}\n" "$*" 2>&1 ; }
warn() { printf "${_orange}%b${_reset}\n" "$*"; printf "%b\n" "$*" >> $LOG_FILE; }
fail() { printf "\n${_red}ERROR: $*${_reset}\n"; printf "\nERROR: $*\n" >> $LOG_FILE; }


# Traps for completion and error
cleanup() {
    ERR_CODE=$?
    log "\nThank you for trying out Autolab! For questions and comments, email us at $OUR_EMAIL.\n"
    [ -z "$PSWD_REMINDER" ] || logstdout "As a final reminder, your MySQL root password is: $PSWD_REMINDER."


    unset MYSQL_ROOT_PSWD
    unset PSWD_REMINDER
    exit ${ERR_CODE:-0}
}

err_report() {
    ERR_CODE=$?

    # Ignore Ctrl-C interrupts
    if [ $ERR_CODE == 130 ];
    then
        return
    fi

    # Handle normal errors
    ERR_LINE=`sed -n "$1p" < $SCRIPT_PATH | sed -e 's/^[ \t]*//'`
    warn "Failed command: $ERR_LINE"
    fail "Line $1 of script has return value $ERR_CODE. The log file is saved at $LOG_FILE."
    exit $ERR_CODE
}

trap 'cleanup' EXIT
trap 'err_report $LINENO' ERR


############################################
## Setup Task Specifications
############################################

old_cleanup() {
  log "[0/7] Cleaning up old installation files"
  sudo rm -rf ./Autolab
  sudo rm -rf ./Tango
}

environment_setup() {
  log "[1/7] Installing docker and docker-compose"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    command -v docker ps >/dev/null 2>&1 || { echo "Autolab on OS X requires Docker. Please install it from https://docs.docker.com/engine/installation/mac/ Aborting." >&2; exit 1; }
  else
    sudo apt-get -y update
    #install relative packages
    sudo apt-get install -y vim git curl python-pip
    #install docker
    curl -sSL https://get.docker.com/ | sh
    #install docker-compose
    pip install docker-compose
    log "[1/7] Done"
  fi
}

source_file_download() {
  log "[2/7] Downloading source file..."
  git clone https://github.com/thotypous/Tango.git
  git clone https://github.com/thotypous/Autolab
  log "[2/7] Done"
}

copy_config() {
  log "[3/7] Copying config files..."

  cp ./prebuilt/ngx_http_shibboleth_module.so ./Autolab/docker/ngx_http_shibboleth_module.so

  cp ../cover/start.sh ./Tango/start.sh
  cp ../cover/Dockerfile ./Autolab/Dockerfile
  cp ../cover/Dockerfile.tango ./Tango/Dockerfile
  cp ../cover/autolab.rake ./Autolab/lib/tasks/autolab.rake

  if [ "$OPTION" == "local" ]
    then
      cp ../cover/autograde.rb ./Autolab/app/controllers/assessment/autograde.rb
  fi

  #User customize
  cp ./configs/config.py ./Tango/config.py
  cp ./configs/autogradeConfig.rb ./Autolab/config/autogradeConfig.rb
  cp ./configs/devise.rb ./Autolab/config/initializers/devise.rb
  cp ./configs/nginx.conf ./Autolab/docker/nginx.conf
  cp ./configs/production.rb ./Autolab/config/environments/production.rb
  cp ./Autolab/config/school.yml.template ./Autolab/config/school.yml

  cp ./configs/mossnet ./Autolab/docker/mossnet

  cp ./configs/attribute-map.xml ./Autolab/docker/attribute-map.xml
  cp ./configs/shibboleth2.xml ./Autolab/docker/shibboleth2.xml
  cp ./configs/sp-key.pem ./Autolab/docker/sp-key.pem
  cp ./configs/sp-cert.pem ./Autolab/docker/sp-cert.pem

  log "[3/7] Done"
}


make_volumes() {
  log "[4/7] make volumes..."

  mkdir ./Autolab/courses
  sudo chown -R 9999:9999 Autolab/courses
  # create attachements folder
  mkdir ./Autolab/attachments
  log "[4/7] Done"
}

init_docker() {
  log "[5/7] Init docker images and containers..."

  docker-compose up -d
  sleep 10
  log "[5/7] Done"
}

init_certbot() {
  log "[6/7] Init certbot..."

  docker-compose exec web certbot --nginx -d autolab.ufscar.br

  log "[6/7] Done"
}

init_database() {
  log "[7/7] Init database..."

  docker-compose run --rm -e RAILS_ENV=production web rake db:create
  docker-compose run --rm -e RAILS_ENV=production web rake db:migrate
  docker-compose run --rm -e RAILS_ENV=production web rake autolab:populate

  cp -r ./Autolab/examples/hello/ ./Autolab/courses/AutoPopulated/hello/
  chown -R 9999:9999 ./Autolab/courses/AutoPopulated/hello

  log "[7/7] Done"
}

congrats() {
  log "[Congratulations! Autolab installation finished]\n
  - Open your browser and visit ${_orange}localhost:80${_reset} you will see the landing page\n
  - Log in with the initial account we create for you to try:\n${_orange}
  - Username: admin@foo.bar\n
  - password: adminfoobar
  ${_reset}
  - Contact us if you have any questions!"
}

#########################################################
## Main Entry Point
#########################################################
cd $OPTION
old_cleanup
environment_setup
source_file_download
copy_config
make_volumes
init_docker
init_certbot
init_database
congrats
