#!/bin/bash

cd ~/jenkins-tools
git pull

exec java -jar ~/slave.jar
