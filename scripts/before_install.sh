#!/bin/bash

set -e -x -u

# Dummy executable files generated for tests use #!/usr/local/bin/bash
sudo mkdir -p /usr/local/bin
sudo ln -s /bin/bash /usr/local/bin/bash
/usr/local/bin/bash --version
