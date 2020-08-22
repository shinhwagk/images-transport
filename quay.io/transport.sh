#!/usr/bin/env bash

DOCKERHUB_OWNER=shinhwagk
DOCKERHUB_IMAGE_PREFIX="quayio"
registry="quay.io"
RequestLimit=100
current_ts=$(date -d "`date -d '-1 day' '+%F'`" +%s)

RenameImage(){
    local image_name=${1//\//_} # replace / to _
    echo "${DOCKERHUB_OWNER}/${DOCKERHUB_IMAGE_PREFIX}_${image_name}:${2}"
}

# exist if return http_code: 200
checkImageExistInDockerHub(){
	local image_name=${1//\//_} 
  curl -s -o /dev/null -w "%{http_code}" https://hub.docker.com/v2/repositories/${image_name}/tags/${2}
}

func_output_tags (){
  curl -s "https://quay.io/api/v1/repository/${1}/tag/?limit=100&page=${2}&onlyActiveTags=true" | jq -c .tags[]
}

func_tags() {
    echo "${1}" | base64 -d | jq '.tags[].name'
}

func_transport() {
    docker pull -q ${registry}/${1}:${2}
    dockerioImage=`RenameImage $1 $2`
    docker tag ${registry}/$1:${2} ${dockerioImage}
    docker push ${dockerioImage} > /dev/null
}

func_image_transport() {
    local image=${1}
    local page=1

    while true; do
        for tagobj in `func_output_tags ${image} ${page}`; do
          local name=$(echo ${tagobj} | jq .name)
          local start_ts=$(echo ${tagobj} | jq .start_ts)

          let page+=1

          if [[ $start_ts -lt $current_ts ]]; then
            echo "process ${image} ${page}."
            local exist=`checkImageExistInDockerHub ${image} ${tag}`
            [ "${exist}" == "200" ] && continue || func_transport $image $tag
          else
						return
					fi
				done
    done
}

bootstrap(){
    cat "${registry}/images" | while read image; do
        func_image_transport ${image}
    done
}

bootstrap