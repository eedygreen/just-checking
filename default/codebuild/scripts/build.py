import logging
import os
import sys

from bitso import docker
from bitso import slack
from bitso.process import execute
from bitso import spinnaker

from . import utils

GRADLE_IMAGE = "gradle:6.8.3-jdk15"

# Avaible CodeBuild environment variables can be found at
# https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html

AWS_ACCOUNT_ID = os.environ.get("AWS_ACCOUNT_ID")
AWS_REGION = os.environ.get("AWS_REGION")
CODEBUILD_RESOLVED_SOURCE_VERSION = os.environ["CODEBUILD_RESOLVED_SOURCE_VERSION"]
LOG_FORMAT = os.environ.get(
    "LOG_FORMAT", "%(asctime)s-%(levelname)s:%(name)s - %(message)s"
)

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
REGISTRY = f"{AWS_ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com"
GITHUB_ACTOR = os.environ.get("GITHUB_ACTOR")
GITHUB_TOKEN = os.environ.get("GITHUB_READ_TOKEN")

SERVICE_NAME = "default"

logging.basicConfig(level=LOG_LEVEL, stream=sys.stdout, format=LOG_FORMAT)


def main():
    f"""Build the {SERVICE_NAME} docker."""
    prepare_build_context()
    compile_jars()

    try:
        notify("STARTED")
        build_project()
        notify("SUCCEEDED")

        if utils.is_prod():
            slack.send_notification(action="SUCCEEDED", channel="release-prod")

        if not utils.is_prod():
            spinnaker.trigger_webhook(
                environment=utils.get_environment_from_current_branch(
                    utils.get_current_branch()
                ),
                image_tag=utils.get_image_tag(),
                kube_cluster="eks",
                project_name=SERVICE_NAME,
            )
    except Exception as e:
        notify("FAILED", annotation=e)
        utils.notify_bort(SERVICE_NAME, "FAILED")

        raise e


def prepare_build_context():
    """Starts Gradle container"""
    logger = logging.getLogger(__name__).getChild(main.__name__)

    filesystem_path = os.path.abspath(".")
    shared_volumes = {
        filesystem_path: {"bind": f"/{SERVICE_NAME}", "mode": "rw"},
    }

    logger.info("Starting Gradle")
    docker.run(
        GRADLE_IMAGE,
        environment=[
            f"GITHUB_ACTOR={GITHUB_ACTOR}",
            f"GITHUB_TOKEN={GITHUB_TOKEN}",
        ],
        command="cat",
        name="gradle",
        detach=True,
        hostname="gradle",
        tty=True,
        volumes=shared_volumes,
    )


def compile_jars():
    cmd = "gradle --no-daemon build -x test"

    docker_execute_or_fail("gradle", cmd=cmd, workdir=f"/{SERVICE_NAME}")


def build_project():
    logger = logging.getLogger(__name__).getChild(main.__name__)

    logger.info(f"Building {SERVICE_NAME}")

    docker_build_path = "."
    dockerfile_path = "docker/Dockerfile"

    execute(f"cp app/build/libs/{SERVICE_NAME}.jar {docker_build_path}/build/")

    image_name = f"{REGISTRY}/bitso/{SERVICE_NAME}:{utils.get_image_tag()}"
    output = docker.build(
        path=docker_build_path, pull=True, tag=image_name, dockerfile=dockerfile_path
    )

    if output is None:
        raise Exception(f"Error building image {image_name}")

    log_push_process(output)

    if not (docker.push(image_name)):
        raise Exception(f"Error pushing image {image_name}")

    logger.info(f"Pushed succeeded for: {image_name}")


def docker_execute_or_fail(container, **args):
    logger = logging.getLogger(__name__).getChild(main.__name__)

    cmd = args["cmd"]
    logger.debug(f"Executing: {cmd}")
    (exit_code, output) = docker.execute(
        container,
        **args,
    )

    if exit_code != 0:
        logger.info(output)
        raise Exception(f"Fail to execute: {cmd}")


def log_push_process(output):
    """Prints only the stream keys from a docker push process."""
    logger = logging.getLogger(__name__).getChild(main.__name__)

    for json in output:
        if "stream" in json:
            logger.info(json["stream"].rstrip())


def notify(action, annotation=None):
    """Wrapping the action and project name for notifications"""
    slack.send_notification(
        action=action, annotation=annotation, job_name=f"{SERVICE_NAME}"
    )


if __name__ == "__main__":
    main()
