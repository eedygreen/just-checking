import logging
import os

from bitso.bort import Bort
from bitso.git import get_current_branch
from bitso.cache import Cache, CacheConfig
import boto3


LOGGER = logging.getLogger(__name__)

# Avaible CodeBuild environment variables can be found at
#  https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html
CODEBUILD_RESOLVED_SOURCE_VERSION = os.environ.get("CODEBUILD_RESOLVED_SOURCE_VERSION")
CODEBUILD_SRC_DIR = os.environ.get("CODEBUILD_SRC_DIR")

# Custom env variables
BORT_API_KEY = os.environ.get("BORT_API_KEY", "notoken")
BORT_API_URL = "https://dkhgjbe8qb.execute-api.us-east-2.amazonaws.com/tools"
CACHE_BUCKET_NAME = os.environ.get("CACHE_BUCKET_NAME", "bitso-dev-codebuild-cache")
CACHE_OBJECTS = []
PROD_BRANCH = "main"


# We need the first 9 chars from the commit hash to match tags from images
# used by Spinnaker
GIT_SHORT_SHA = CODEBUILD_RESOLVED_SOURCE_VERSION[0:9]

bort = Bort(bort_api_key=BORT_API_KEY, bort_api_url=BORT_API_URL)
cache_client = None


def get_image_tag():
    """Image tag is {branch_name}-{git_sha} unless the environment is prod, in which case
    the image tag will be {git-sha}."""
    branch = get_current_branch()

    if branch == PROD_BRANCH:
        return GIT_SHORT_SHA

    return f"{branch}-{GIT_SHORT_SHA}"


def get_environment_from_current_branch(branch):
    switcher = {"main": "prod", "development": "dev", "staging": "stage", "sandbox": "sandbox"}
    return switcher.get(branch, branch)


def is_prod():
    return get_current_branch() == PROD_BRANCH


def is_branch_managed_by_bort():
    """
    Identify if the branch is managed by Bort
    """
    return bort.is_a_managed_branch(get_current_branch())


def notify_bort(service, state):
    """Notify Bort about the codebuild result"""
    if not is_branch_managed_by_bort():
        return

    # Notify bort to release lock
    image_tag = get_image_tag()
    LOGGER.info(
        "Notify bort to release the lock for the hash: %s with state %s",
        image_tag,
        state,
    )

    encoded_body = {
        "pipeline": service,
        "application": service,
        "id": "0",
        "state": state,
        "sha": image_tag,
    }

    response = bort.notify(encoded_body)

    LOGGER.info("Bort status code: %s", response.status_code)


def init_cache():
    """Get objects from cache"""
    cache = __get_cache_client()
    for object in CACHE_OBJECTS:
        cache.get_object(object)


def store_cache():
    """Store objects to cache"""
    cache = __get_cache_client()
    for object in CACHE_OBJECTS:
        cache.put_object(object)


def __get_cache_client():
    """Get cache client"""
    if cache_client:
        return cache_client

    # create cache client
    environment = get_environment_from_current_branch(get_current_branch())

    config = CacheConfig(
        build_project="default",
        cache_bucket=CACHE_BUCKET_NAME,
        environment=environment,
    )
    s3 = boto3.resource("s3")

    CACHE = Cache(config, s3)
    return CACHE
