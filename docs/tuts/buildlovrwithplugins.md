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