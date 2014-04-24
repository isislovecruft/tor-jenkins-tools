#!/bin/bash

cd ~/jenkins-tools
git pull

exec java -Dorg.jenkinsci.plugins.gitclient.Git.useCLI=true -jar ~/slave.jar
