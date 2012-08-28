#!/bin/bash

cd /opt/webistrano
bundle exec ruby script/server -d -p 3000 -e production
