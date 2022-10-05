#!/bin/bash

target_name=$1
target_dir=$2

sudo apt update -y 
sudo apt install -y snap jq unzip
sudo snap install  go --classic

go install github.com/tomnomnom/fff@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/OWASP/Amass/v3/...@master
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/tomnomnom/httprobe@latest

curl -sL "https://raw.githubusercontent.com/epi052/feroxbuster/master/install-nix.sh" | bash

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

wget "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/directory-list-lowercase-2.3-medium.txt" -O ~/go/bin/directory-list.txt

for file in $(find $storage_dir -name *.body)
do 
    cat $file | jq -r '.dependencies + .devDependencies' | cut -d : -f 1 | tr -d '"|}|{' | sort -u | tr -s "     " | sort -u | xargs -n1 -I{} echo "https://registry.npmjs.org/{}" | grep -v "@" | ~/go/bin/httpx -status-code -silent -content-length -mc 404 -o $storage_dir/datarepofile
done

~/go/bin/httpx -l $storage_dir/domain_file -sc -mc 200 -o $storage_dir/domain200

for file in $(cat $storage_dir/domain200 | cut -d' ' -f1)
do 
    filename=$(echo $file | md5sum | cut -d' ' -f1)
    ./feroxbuster -d $file -w ~/go/bin/directory-list.txt -o "$storage_dir/domainferox_($filename).txt" -t 100 
done


