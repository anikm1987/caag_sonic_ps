#!/bin/bash
rm -rf node_modules dist package-lock.json
npm install
npm cache clean --force
npm run build
cd terraform
terraform init
terraform apply
