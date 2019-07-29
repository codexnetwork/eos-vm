DRYRUN=${DRYRUN:-false}
VERBOSE=${VERBOSE:-true}
export PROJECT_NAME="eos-vm"
export IMAGE_TAG=${IMAGE_TAG:-"ubuntu-18.04"}

function execute() {
  $VERBOSE && echo "--- Executing: $@"
  $DRYRUN || "$@"
}

function determine-hash() {
    # Determine the sha1 hash of all dockerfiles in the .cicd directory.
    [[ -z $1 ]] && echo "Please provide the files to be hashed (wildcards supported)" && exit 1
    echo "Obtaining Hash of files from $1..."
    # Collect all files, hash them, then hash those.
    HASHES=()
    for FILE in $(find $1 -type f); do
        HASH=$(sha1sum $FILE | sha1sum | awk '{ print $1 }')
        HASHES=($HASH "${HASHES[*]}")
        echo "$FILE - $HASH"
    done
    export DETERMINED_HASH=$(echo ${HASHES[*]} | sha1sum | awk '{ print $1 }')
    export HASHED_IMAGE_TAG="${IMAGE_TAG}-${DETERMINED_HASH}"
}

function generate_docker_image() {
    # If we cannot pull the image, we build and push it first.
    docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_PASSWORD
    cd ./.cicd
    docker build -t $FULL_TAG -f ./${IMAGE_TAG}.dockerfile .
    docker push $FULL_TAG
    cd -
}

function docker_tag_exists() {
    ORG_REPO=$(echo $1 | cut -d: -f1)
    TAG=$(echo $1 | cut -d: -f2)
    EXISTS=$(curl -s -H "Authorization: Bearer $(curl -sSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${ORG_REPO}:pull" | jq --raw-output .token)" "https://registry.hub.docker.com/v2/${ORG_REPO}/manifests/$TAG")
    ( [[ $EXISTS =~ '404 page not found' ]] || [[ $EXISTS =~ 'manifest unknown' ]] ) && return 1 || return 0
}

determine-hash ".cicd/${IMAGE_TAG}.dockerfile"
export FULL_TAG="eosio/producer:${PROJECT_NAME}-$HASHED_IMAGE_TAG"