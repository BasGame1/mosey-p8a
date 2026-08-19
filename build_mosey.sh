#!/bin/bash
build_mosey() {

 set -e
 
 FILES="out/module/wonder_mosey_wild.ko customize.sh module.prop sepolicy.rule service.sh uninstall.sh"
 FOLDERS="common META-INF payload system"
 if [ ! -z out/zip ]; then
  echo "Creating zip out folder"
  mkdir -p out/zip
 fi
 for i in $FILES; do
  if [ ! -f $i ]; then
   if [ $i == "wonder_mosey_wild.ko" ]; then
    echo "Kernel module not compile, please compile it first"
    exit
   else
    echo "$i not found, exiting"
    exit 255
   fi
  fi
  mv $i out/zip
 done
}
zip_files() {

 set -e 
 
 zip -r mosey-extended.zip out/zip/*
}
# The function executes only if calling the script from terminal, in case of sourcing it from other script it doesnt execute at start
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    . wonder/build_wonder.sh
    echo "Building wonder"
    build_wonder
    if [ ! -f out/module/wonder_mosey_wild.ko ]; then
     echo "Mosey not built"
     echo "Building mosey"
     build_mosey
    fi
    echo "Finished building"
    echo "Zipping files"
    zip_files
    echo "DONE!"
fi
