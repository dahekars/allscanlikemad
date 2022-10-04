#!/bin/bash

target_name=$1
target_dir=$2

sudo apt update -y 
sudo apt install -y snap jq
sudo snap install  go --classic

go install github.com/tomnomnom/fff@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/OWASP/Amass/v3/...@master
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/tomnomnom/httprobe@latest

wget "https://raw.githubusercontent.com/projectdiscovery/nuclei-templates/master/exposures/configs/package-json.yaml" -O ~/go/bin/nuclei_package_scan.yaml

storage_dir=$target_dir/$target_name

mkdir -p $storage_dir

~/go/bin/subfinder -d $target_name | tee -a $storage_dir/domain_file
~/go/bin/amass enum -passive -d $target_name | tee -a $storage_dir/domain_file

cat $storage_dir/domain_file | sort -u |tee -a $storage_dir/domain

domains_list=$storage_dir/domain

~/go/bin/httpx -l $domains_list -o $storage_dir/domain_file_for_nuclei; wc -l $storage_dir/*

~/go/bin/nuclei -l $storage_dir/domain_file_for_nuclei -t ~/go/bin/nuclei_package_scan.yaml -o $storage_dir/nuclei_package_scan 

cat $storage_dir/nuclei_package_scan | cut -d' ' -f6 | ~/go/bin/fff -s 200 -o $storage_dir/package_scan

for file in $(find $storage_dir -name *.body)
do 
    cat $file | jq -r '.dependencies + .devDependencies' | cut -d : -f 1 | tr -d '"|}|{' | sort -u | tr -s "     " | sort -u | xargs -n1 -I{} echo "https://registry.npmjs.org/{}" | grep -v "@" | ~/go/bin/httpx -status-code -silent -content-length -mc 404 -o $storage_dir/datarepofile
done
