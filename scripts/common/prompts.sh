#!/bin/bash

yn_prompt() {
  local prompt_text=$1
  local var_name=$2

  if [[ -z $QUIET_MODE ]];
  then
      if [[ "${!var_name}" == "false" ]];
      then
        local prompt_options="(y/[n])"
        local prompt_nondefault="y"
        local value_nondefault="true"
      else
        local prompt_options="([y]/n)"
        local prompt_nondefault="n"
        local value_nondefault="false"
      fi  

      read -r -p "${prompt_text}? ${prompt_options}" INPUT_VALUE
      if [[ "${INPUT_VALUE}" == "${prompt_nondefault}" ]];
      then
        printf -v "${var_name}" "%s" "${value_nondefault}"
      fi
  fi
}