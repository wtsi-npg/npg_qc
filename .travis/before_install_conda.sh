wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh -O miniconda.sh

/bin/bash miniconda.sh -b -p "$HOME/miniconda"
export PATH="$HOME/miniconda/bin:$PATH"
hash -r

conda config --set always_yes yes
conda config --set changeps1 no
conda config --set show_channel_urls true
conda update -q conda

conda config --add channels $CONDA_CHANNEL

# Useful for debugging any issues with conda
conda info -a
