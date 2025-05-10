windows
```shell
git clone --recursive https://github.com/bjornbytes/lovr.git
cd lovr
cd plugins
git clone --recursive https://github.com/brainrom/lovr-luasocket.git
git clone --recursive https://github.com/bjornbytes/lua-cjson.git
cd ..
mkdir Release
cd Release
cmake -DUSE_AVX=OFF -DUSE_AVX2=OFF -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release
```

ubuntu
```shell
sudo apt install make cmake xorg-dev libcurl4-openssl-dev libxcb-glx0-dev libx11-xcb-dev python3-minimal
git clone --recursive https://github.com/bjornbytes/lovr.git
cd lovr
cd plugins
git clone --recursive https://github.com/brainrom/lovr-luasocket.git
git clone --recursive https://github.com/bjornbytes/lua-cjson.git
cd ..
mkdir Release
cd Release
cmake -DUSE_AVX=OFF -DUSE_AVX2=OFF -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release
```
