#!/bin/bash
# Update system
sudo yum update -y

# Remove old Docker packages
for pkg in docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine; do
    sudo yum remove -y $pkg
done

# Install required packages
sudo yum install -y yum-utils curl unzip make jq git

sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker $USER
# exit and relogin to the session for docker group changes to take effect
# Install pyenv dependencies
sudo yum groupinstall -y "Development Tools"
sudo yum install -y gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
openssl-devel xz xz-devel libffi-devel findutils

# Install pyenv
curl -fsSL https://pyenv.run | bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# Install Python via pyenv
pyenv install 3.11.3
pyenv global 3.11.3

# Install NVM and Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install v22.16.0
nvm use v22.16.0

# Install Terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Apply patches and updates
sudo yum update -y