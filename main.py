# from lyrics.SpotifyLyricsListener import start
from ll_kugou_lyric_api.core import KugouApi
import base64
import sys
sys.dont_write_bytecode = True


# if __name__ == "__main__":
#    # 指定False则是正式环境
#    # start(False)
#    print(KugouApi("朵","赵雷").get_kugou_lrc())
#    start()
   
def sb3(title,artist):
   print(KugouApi(title,artist).get_kugou_lrc())