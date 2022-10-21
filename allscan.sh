#!/bin/bash

target_name=$1
target_dir=$2

sudo apt update -y 
sudo apt install -y snap jq unzip tmux gcc
sudo snap install  go --classic

go install github.com/tomnomnom/fff@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/OWASP/Amass/v3/...@master
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/tomnomnom/httprobe@latest

curl -sL "https://raw.githubusercontent.com/epi052/feroxbuster/master/install-nix.sh" | bash

#wget "https://raw.githubusercontent.com/projectdiscovery/nuclei-templates/master/exposures/configs/package-json.yaml" -O ~/go/bin/nuclei_package_scan.yaml

wget "https://github.com/projectdiscovery/nuclei-templates/archive/refs/heads/master.zip" -O nuclei-temp.zip

unzip nuclei-temp.zip 

mkdir temp-file

for line in $(find ./nuclei-templates-master/ -type f -name \*.yaml)
	do
		mv $line ./temp-file/ -v
	done

storage_dir=$target_dir/$target_name

mkdir -p $storage_dir

~/go/bin/subfinder -d $target_name | tee -a $storage_dir/domain_file
~/go/bin/amass enum -passive -d $target_name | tee -a $storage_dir/domain_file

cat $storage_dir/domain_file | sort -u |tee -a $storage_dir/domain

domains_list=$storage_dir/domain

~/go/bin/httpx -l $domains_list -o $storage_dir/domain_file_for_nuclei; wc -l $storage_dir/*

for yamlfile in $(find ./temp-file/ -type f -name \*.yaml | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1)
do 

echo -e "\n Scan for $yamlfile scan \n"

~/go/bin/nuclei -l $storage_dir/domain_file_for_nuclei -t ./temp-file/$yamlfile* -o "$storage_dir/domain_$yamlfile"
done

#for yamlname in $(find ./temp-file/ -type f -name \*.yaml | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1) ; do touch domain_$yamlname; done

cat $storage_dir/nuclei_package_scan | cut -d' ' -f6 | ~/go/bin/fff -s 200 -o $storage_dir/package_scan

wget "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/directory-list-lowercase-2.3-medium.txt" -O ~/go/bin/directory-list.txt

for file in $(find $storage_dir -name *.body)
do 
    cat $file | jq -r '.dependencies + .devDependencies' | cut -d : -f 1 | tr -d '"|}|{' | sort -u | tr -s "     " | sort -u | xargs -n1 -I{} echo "https://registry.npmjs.org/{}" | grep -v "@" | ~/go/bin/httpx -status-code -silent -content-length -mc 404 -o $storage_dir/datarepofile
done

~/go/bin/httpx -l $storage_dir/domain_file -sc -mc 200 -o $storage_dir/domain200

for file in $(cat $storage_dir/domain200 | cut -d' ' -f1)
do 
    filename=$(echo $file | md5sum | cut -d' ' -f1)
    ./feroxbuster -u $file -w ~/go/bin/directory-list.txt -o "$storage_dir/domainferox_($filename).txt" -t 100 
done


