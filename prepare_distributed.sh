git clone --recursive https://github.com/shiyu1994/LightGBM.git
cd LightGBM
git checkout cuda-discretized-nccl3
git submodule update --init
mkdir build
cd build
cmake .. -DUSE_TIMETAG=ON
make -j
cd ..
cd ..
wget https://azcopyvnext.azureedge.net/release20220315/azcopy_linux_amd64_10.14.1.tar.gz
tar xvzf azcopy_linux_amd64_10.14.1.tar.gz
echo "export PATH=\$PATH:$PWD/azcopy_linux_amd64_10.14.1/" >> ~/.bashrc
source ~/.bashrc
azcopy copy "https://fastbertjp.blob.core.windows.net/shiyu/lgb_data/epsilon20X.train?sv=2020-10-02&st=2022-10-11T06%3A32%3A20Z&se=2022-10-12T06%3A32%3A20Z&sr=b&sp=r&sig=awAaT1AZJmbNQcErt4AEyvx8a1GpEoQre%2Bw0csvyH88%3D" .
azcopy copy "https://fastbertjp.blob.core.windows.net/shiyu/lgb_data/epsilon.test?sv=2020-10-02&st=2022-10-11T06%3A33%3A04Z&se=2022-10-12T06%3A33%3A04Z&sr=b&sp=r&sig=RAShdxnbnapUtvAMK8wWrjyZncftFNJwSX4koLS9by8%3D" .
