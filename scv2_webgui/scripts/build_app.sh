#!/bin/bash

# Cheatsheet:
# $0 gives current working directory
# realpath <path> gives full absolute path
# dirname <path> moves up one directory level from path
# env lists all environment variables
# pushd <path> sets current working directory to path
# popd pops the current working directory that was set by pushd

# First, The following env variables can be specified at build time (i.e. upon execution of this script)
# to overwrite any of the env variables specified by default in /configs/.env
# DB_PROTOCOL
# DB_HOST
# DB_PORT
# GIF_PORT
# GHOST_DEFAULT
# END_TIME
# OFFLINE_DB
# DEBUG
# SERVICE_WORKER
# CLASSIFIER_PORT

# Pathing
this_script_relative_path=$0
this_script_full_path=$(realpath $this_script_relative_path)
scripts_folder_path=$(dirname $this_script_full_path)
root_project_folder_path=$(dirname $scripts_folder_path)

# Change the current directory
cd $root_project_folder_path

# Lastly, run the cross-env with all env vars set
npx cross-env \
  DB_PROTOCOL=$DB_PROTOCOL \
  DB_HOST=$DB_HOST \
  DB_PROTOCOL=$DB_PORT \
  GIF_PORT=$GIF_PORT \
  GHOST_DEFAULT=$GHOST_DEFAULT \
  END_TIME=$END_TIME \
  OFFLINE_DB=$OFFLINE_DB \
  DEBUG=$DEBUG \
  SERVICE_WORKER=$SERVICE_WORKER \
  CLASSIFIER_PORT=$CLASSIFIER_PORT \
  webpack --config webpack.config.babel.js