
if [[ "$TRAVIS_PYTHON_VERSION" == "2.7" ]]; then
    wget -q -w 30 https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh -O miniconda.sh;
else
    wget -q -w 30 https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh;
fi

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
