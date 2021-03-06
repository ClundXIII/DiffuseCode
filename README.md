Diffuse program collection
================================================================

Welcome to the 'diffuse program' collection.
The website can be found at http://tproffen.github.io/DiffuseCode

Depending on the package you have downloaded you will find one or all of the
following program directories after unpacking the archive.

DISCUS  : Diffuse Scattering & Defect Structure Simulation
AUTHORS : R.B. Neder  (reinhard.neder@fau.de)
          Th. Proffen (tproffen@ornl.gov)

DIFFEV  : Generic refinement program using evolutionary algoritm
AUTHOR  : R.B. Neder  (reinhard.neder@fau.de)

KUPLOT  : General plotting program (well suited for DISCUS output)
AUTHOR  : Th. Proffen (tproffen@ornl.gov)
          R.B. Neder  (reinhard.neder@fau.de)

MIXSCAT : Program to generate differential PDFs from n/X data
AUTHOR  : C. Wurden K. Page A. Llobet
          Th. Proffen (tproffen@ornl.gov)

INSTALLATION
================================================================

Binary
------

Binary distributions as well as the source code can be found 
at https://github.com/tproffen/DiffuseCode/releases

Linux
-----

To build from the source code, you need gfortran (> 4.6.x) as
well as cmake installed. Here is the simple set of commands 
to build the programs from the source:

Download the source code from GitHub https://github.com/tproffen/DiffuseCode/releases

Goto working directory and unpack

    cd your-working-directory
    tar -xvzf DiffuseCode-vX.X.X.tar.gz

Create build directory

    mkdir DiffuseBuild
    cd DiffuseBuild

Invoke cmake.
  
    cmake ../DiffuseCode-vX.X.X

Now build and install

    make
    sudo make install

For further details, please check file [AAA_INSTALL_DISCUS.pdf](Manual/AAA_INSTALL_DISCUS.pdf) in the directory Manual.

OSX - Using homebrew
---

1. Install [XCode](https://developer.apple.com/xcode/download/), [XQuartz](http://www.xquartz.org/) and [Homebrew](http://brew.sh/)
2. Download and extract the source code from [here](https://github.com/tproffen/DiffuseCode/releases), `cd` into that directory
2. command line build:

```
$ brew install cmake
$ brew install gcc  # Very slow
$ brew install homebrew/x11/pgplot
$ CC=gcc-5 CXX=g++-5 FC=gfortran cmake .
$ make
$ sudo make install
```

You may receive some warnings but it should install successfully. Check by seeing if you can run the command `discus`.

Windows
-------

Recommend you install the binary found [here](https://github.com/tproffen/DiffuseCode/releases).

Instructions to build from source please check file [AAA_INSTALL_DISCUS_CYGWIN.pdf](Manual/AAA_INSTALL_DISCUS_CYGWIN.pdf).


[![Build Status](https://travis-ci.org/tproffen/DiffuseCode.svg?branch=master)](https://travis-ci.org/tproffen/DiffuseCode)
