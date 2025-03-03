# clush -a -b  mkdir -p ./demo
# clush -a -b  mkdir -p ./demo/scripts
# clush -a -b  mkdir -p ./demo/scripts/utils
# clush -a -b  mkdir -p ./demo/models
# clush -a -b  mkdir -p ./demo/logs
# clush -a -b  mkdir -p ./demo/status
# clush -a -b  ls -d ./demo

# Copying Parameter file to all nodes
clush -a -b rm -r ./demo/scripts/
clush -a -b mkdir -p ./demo/scripts
clush -a -b --copy * --dest ./demo/scripts/
# clush -a --copy ../parameters.sh --dest ./demo/scripts
# clush -a --copy ../../models/* --dest ./demo/models
