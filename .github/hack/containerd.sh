#!/bin/bash
kubeVersion=${1:-1.22.8}
containerdVersion=1.6.2
ipvsImage=ghcr.io/labring/lvscare:v1.1.3-beta.7
lvscareVersion=latest
os=linux
arch=${2:-amd64}
#https://github.91chi.fun//
repo=${3:-docker.io/cuisongliu}
proxy=${4:-}
buildDir=.build-image
# init dir
mkdir -p $buildDir/bin && mkdir -p $buildDir/opt && mkdir -p $buildDir/registry && mkdir -p $buildDir/images/shim && mkdir -p $buildDir/cri/lib64
cp -rf rootfs/* $buildDir/
cp -rf containerd/* $buildDir/
# library install
wget https://sealyun-home.oss-accelerate.aliyuncs.com/images/library-2.5-$os-$arch.tar.gz --no-check-certificate -O library.tar.gz
tar xf library.tar.gz && rm -rf library.tar.gz
cp -rf library/bin/*    $buildDir/bin/
ls -l  $buildDir/bin/
cp -rf library/lib64/  $buildDir/cri/lib64/lib
ls -l $buildDir/cri/lib64/lib
rm -rf library
cd $buildDir/cri/lib64 && tar -czf containerd-lib.tar.gz lib && rm -rf lib && cd ../../../
#kube install
wget https://storage.googleapis.com/kubernetes-release/release/v$kubeVersion/bin/$os/$arch/kubectl -O $buildDir/bin/kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v$kubeVersion/bin/$os/$arch/kubelet -O $buildDir/bin/kubelet
wget https://storage.googleapis.com/kubernetes-release/release/v$kubeVersion/bin/$os/$arch/kubeadm -O $buildDir/bin/kubeadm
# registry install
wget https://sealyun-home.oss-accelerate.aliyuncs.com/images/registry-$arch.tar --no-check-certificate -O $buildDir/images/registry.tar
# cri install
wget https://github.com/containerd/containerd/releases/download/v$containerdVersion/cri-containerd-cni-$containerdVersion-linux-$arch.tar.gz --no-check-certificate -O cri-containerd-cni-linux.tar.gz
tar -zxf  cri-containerd-cni-linux.tar.gz
rm -rf etc opt && mkdir -p usr/bin
cp -rf usr/local/bin/* usr/bin/
cp -rf usr/local/sbin/* usr/bin/ && rm -rf usr/bin/critest && rm -rf cri-containerd-cni-$os.tar.gz usr/local
tar -czf cri-containerd-linux.tar.gz usr && rm -rf usr
mv cri-containerd-linux.tar.gz $buildDir/cri/
# nerdctl install
wget ${proxy}https://github.com/containerd/nerdctl/releases/download/v0.16.0/nerdctl-0.16.0-$os-$arch.tar.gz -O  nerdctl.tar.gz
tar xf nerdctl.tar.gz
mv nerdctl $buildDir/cri/
rm -rf nerdctl.tar.gz containerd-rootless*
# shim install
wget ${proxy}https://github.com/labring/image-cri-shim/releases/download/v0.0.8/image-cri-shim_0.0.8_${os}_${arch}.tar.gz -O image-cri-shim.tar.gz
mkdir -p crishim && tar -zxf image-cri-shim.tar.gz -C crishim
mv crishim/image-cri-shim $buildDir/cri/
rm -rf image-cri-shim.tar.gz crishim
# sealctl
wget https://sealyun-home.oss-accelerate.aliyuncs.com/sealos-4.0/$lvscareVersion/sealctl-$arch --no-check-certificate -O $buildDir/opt/sealctl
# lsof
wget https://sealyun-home.oss-accelerate.aliyuncs.com/images/lsof-$os-$arch --no-check-certificate -O $buildDir/opt/lsof
# images
echo "$ipvsImage" >  $buildDir/images/shim/DefaultImageList
if [ ! -f ./kubeadm ];then
  wget https://storage.googleapis.com/kubernetes-release/release/v$kubeVersion/bin/linux/amd64/kubeadm
  chmod a+x kubeadm
fi
./kubeadm config images list --kubernetes-version $kubeVersion  2>/dev/null>> $buildDir/images/shim/DefaultImageList
rm -rf kubeadm
# Kubefile
sed -i "s/v0.0.0/v$kubeVersion/g" ./$buildDir/Kubefile
sed -i "s#__lvscare__#$ipvsImage#g" ./$buildDir/Kubefile
# replace
pauseImage=$(cat ./$buildDir/images/shim/DefaultImageList  | grep k8s.gcr.io/pause)
sed -i "s#__pause__#k8s.gcr.io/${pauseImage##k8s.gcr.io/}#g" ./$buildDir/etc/kubelet-flags.env
sed -i "s#__pause__#sealos.hub:5000/${pauseImage##k8s.gcr.io/}#g" ./$buildDir/etc/config.toml
cd $buildDir
chmod  -R 0755  *
sealos build -t $repo/kubernetes:v$kubeVersion-$arch --platform $os/$arch -f Kubefile  .
cd ../ && rm -rf $buildDir
