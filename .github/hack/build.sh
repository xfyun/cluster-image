#!/bin/bash
#sh build.sh 1.22.8 registry-vpc.cn-hongkong.aliyuncs.com sealyun sealyun@1244797166814602 xxxx
version=${1:-1.22.8}
domain=${2:-docker.io}
repo=${3:-cuisongliu}
username=${4:-cuisongliu}
password=${5:-}
proxy=${6:-}
prefix=$domain/$repo
sh containerd.sh $version amd64 $prefix $proxy
sh containerd.sh $version arm64 $prefix $proxy
buildah login --username $username --password $password $domain
buildah push $prefix/kubernetes:v$version-amd64
buildah push $prefix/kubernetes:v$version-arm64
buildah manifest create $prefix/kubernetes:v$version
buildah manifest add $prefix/kubernetes:v$version docker://$prefix/kubernetes:v$version-amd64
buildah manifest add $prefix/kubernetes:v$version docker://$prefix/kubernetes:v$version-arm64
buildah manifest push --all $prefix/kubernetes:v$version docker://$prefix/kubernetes:v$version
echo "script $prefix/kubernetes:v$version build successfully!"
