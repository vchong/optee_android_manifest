#!/bin/bash

./sync.sh -t hikey960 -bm pinned-manifest_hikey960_master_v3.9.0_20200703.xml "$@" 2>&1 |tee logs/sync-master.log
#./sync.sh -t hikey960 "$@" 2>&1 |tee logs/sync-p.log
