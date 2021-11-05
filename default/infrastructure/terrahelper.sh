#!/bin/bash
# This shell script reads the TERRAFORM_VERSION from the versions.tf file
# the module MUST use the terraform block settings to specify the version
# that uses.
#
#terraform {
#  required_version = "1.0.0"
#  required_providers {
#    aws = {
#      version = ">= 2.7.0"
#      source = "hashicorp/aws"
#    }
#  }
#}

set -e

ROOT_PATH=$(git rev-parse --show-toplevel)

# Set terraform version in asdf
CURRENT_VERSION=$(terraform version | awk 'FNR == 1 {print $2}' | cut -c2-)
TERRAFORM_VERSION=$(grep required_version versions.tf | cut -d'"' -f 2)

if [ -z ${TERRAFORM_VERSION} ]; then
    # use 1.0.0 as default
    TERRAFORM_VERSION="1.0.0"
fi

if [ "${TERRAFORM_VERSION}" != "${CURRENT_VERSION}" ]; then
    if command -v asdf >/dev/null 2>&1; then
        asdf global terraform "${TERRAFORM_VERSION}"
    else
        echo "Please go to this repo https://github.com/bitsoex/bitso-docker-getting-started and execute bootstrap.sh script to install the proper tools."
        exit 1
    fi
fi

# terrahelper is used to add s3 backend params thereby making terraform execution simpler
# it is intended to stay out of the way of the user and allow them to do everything
# they would with the standard terraform command

print_cmd_error() {
    echo "ERROR: ${1}"
    echo "Correct usage:"
    echo "./terrahelper_v3.sh {apply|create|destroy|init|plan} {ENVIRONMENT} {NAMESPACE} {FLAGS...}"
    echo "e.g. ./terrahelper_v3.sh plan dev dev -var 'someVar=someVal'"
    echo "If NAMESPACE is not applicable simply repeat the ENVIRONMENT"
    echo "ALL FLAGS MUST GO AT THE END!"
}

file_or_error() {
    # $1 is CONFIG_PARAMS
    # $2 is the config flag
    # $3 is the config file path
    # Check that the config file exists
    if [ -f "${3}" ]; then
        # If file exists set it on the CONFIG_PARAMS with provided config flag
        # Spacing is weird here to avoid double spaces - keep it this way
        eval "$1=\"${!1}${2}=${3} \""
    else
        if [ -f "../${3}" ]; then
            eval "$1=\"${!1}${2}=../${3} \""
        else
            print_cmd_error "Required config file ${3} missing"
            exit 1
        fi
    fi
}

switch_to() {
    # If the workspace doesn't exit, then create it
    WORKSPACE_EXIST=$(terraform workspace list | grep ${NAMESPACE} || true)
    if [ -z "${WORKSPACE_EXIST}" ]; then
        echo "Creating new terraform workspace for ${NAMESPACE}"
        terraform workspace new ${1}
    else
        echo "Setting terraform workspace to ${NAMESPACE}"
        terraform workspace select ${1}
    fi

}

execute_terraform_command() {
    ACTION="${1}"
    ENVIRONMENT="${2}"
    NAMESPACE="${3}"

    # Rightmost file takes precedence (last in order)
    CONFIG_PARAMS=""

    if [ "plan" = "${ACTION}" ] || [ "apply" = "${ACTION}" ] || [ "destroy" = "${ACTION}" ]; then
        # This file is required
        file_or_error CONFIG_PARAMS "-var-file" "config/environment/${ENVIRONMENT}.tfvars"

        # Namespace config is optional
        NAMESPACE_CONFIG="config/namespace/${NAMESPACE}.tfvars"
        # Spacing is weird here to avoid double spaces - keep it this way
        if [ -f $NAMESPACE_CONFIG ]; then
            CONFIG_PARAMS="${CONFIG_PARAMS} -var-file=${NAMESPACE_CONFIG}"
        elif [ -f "../${NAMESPACE_CONFIG}" ]; then
            CONFIG_PARAMS="${CONFIG_PARAMS} -var-file=../${NAMESPACE_CONFIG}"
        fi

        switch_to ${NAMESPACE}
    elif [ "init" = "${ACTION}" ]; then
        # This file is required
        file_or_error CONFIG_PARAMS "-backend-config" "config/backend/${ENVIRONMENT}.tfvars"
    else
        print_cmd_error "Terraform action must be one of apply|create|destroy|init|plan"
        exit 1
    fi

    # This ordering is important in case we have any params that need to override
    # config file values
    shift 3
    echo "Executing: terraform ${ACTION} -compact-warnings ${CONFIG_PARAMS} ${@}"
    terraform $ACTION -compact-warnings $CONFIG_PARAMS $@
}

create_project() {
    # Create a new project with a config folder and the override file
    mkdir -p config
    ln -s "${ROOT_PATH}/terraform/globals/override.tf" "override.tf"
    ln -s "${ROOT_PATH}/terraform/globals/common_variables.tf" "common_variables.tf"
}

set_or_error() {
    # Check that the value is set and assign it
    # Aware that this is highly unlikely but try anyway
    if [ -z "${2}" ]; then
        print_cmd_error "${1} missing"
        exit 1
    else
        eval "$1=${2}"
        echo "${1} set to ${!1}"
    fi
}

ACTION=""
set_or_error ACTION "${1}"

if [ "${ACTION}" != "plan" ] && [ "${ACTION}" != "apply" ] &&
    [ "${ACTION}" != "destroy" ] && [ "${ACTION}" != "init" ] &&
    [ "${ACTION}" != "create" ]; then
    print_cmd_error "Action must be apply|create|destroy|init|plan"
fi

ENVIRONMENT=""
set_or_error ENVIRONMENT "${2}"

NAMESPACE=""
set_or_error NAMESPACE "${3}"

shift 3

case $ACTION in
apply | destroy | init | plan)
    execute_terraform_command $ACTION $ENVIRONMENT $NAMESPACE $@
    ;;
create)
    create_project $ENVIRONMENT $NAMESPACE
    ;;
esac
