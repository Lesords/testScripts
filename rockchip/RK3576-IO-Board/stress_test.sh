echo "start mp3" && mpg123 -a hw:0,0 ./test.mp3 &

echo "start ping with end0" && ping -c 10 www.baidu.com -I end0 &
echo "start ping with wlan0" && ping -c 10 www.baidu.com -I wlan0 &

echo "start cpu test " && stress-ng --cpu 8 --timeout 60s &

echo "start video 0" && v4l2-ctl -d /dev/video22 --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
    --stream-mmap --stream-to=/tmp/isp0_10s.raw --stream-count=300 &

echo "start video 1" && v4l2-ctl -d /dev/video31 --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
    --stream-mmap --stream-to=/tmp/isp1_10s.raw --stream-count=300
