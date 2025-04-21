# from lyrics.SpotifyLyricsListener import start
import time
from lyrics.LyricsAdapterFactory import LyricsAdapterFactory
from lyrics.enums import Sources
from lyrics.Communication import RaspberryPiComm
   
def send_kugou_lyrics(id,position,image,status,title,artist,duration):
   start = time.time()  # 秒（float）
   
   if(True):
      # 树莓派默认37
      # 本地默认 33
      # pi_comm = RaspberryPiComm(hostname="192.168.1.37")
      pi_comm = RaspberryPiComm(hostname="192.168.1.33")
   else:
      pi_comm = RaspberryPiComm()
      
   kugouFactory =  LyricsAdapterFactory.get_adapter(Sources.Kugou)
   param = {
      "title":title,
      "artist":artist,
      "duration":duration
   }
   standardLyricsObj = kugouFactory.convert(param)
   end = time.time()
   elapsed_ms = (end - start) * 1000  # 转换为毫秒
   print(f'歌词初始化时间：{elapsed_ms}')
   # 以下数据需要通过接口获得
   standardLyricsObj.set_title(title)
   standardLyricsObj.set_artist(artist)
   standardLyricsObj.set_time(elapsed_ms+position)
   standardLyricsObj.set_image(image)
   standardLyricsObj.set_status(status)
   standardLyricsObj.set_id(id)
   # json = standardLyricsObj.to_json()
   # print(json)

   try:
      pi_comm.send_lyrics(standardLyricsObj.to_json())  
   except Exception as e:
      print("//TODO 通信错误，想办法激活树莓派",e)
   
def sync_play_state(status,position):
   kugouFactory =  LyricsAdapterFactory.get_adapter(Sources.Kugou)
   standardLyricsObj = kugouFactory.convert(None)
   standardLyricsObj.set_time(position)
   standardLyricsObj.set_status(status)
   json = standardLyricsObj.to_json()
   print(json)
   if(True):
      # 树莓派默认37
      # 本地默认 33
      # pi_comm = RaspberryPiComm(hostname="192.168.1.37")
      pi_comm = RaspberryPiComm(hostname="192.168.1.33")
   else:
      pi_comm = RaspberryPiComm()
   try:
      pi_comm.send_lyrics(standardLyricsObj.to_json())  
      # RaspberryPiComm(hostname="192.168.1.33").send_lyrics(standardLyricsObj.to_json())    
   except Exception as e:
      print("//TODO 通信错误，想办法激活树莓派",e)

if __name__ == "__main__":
   pass
   # 指定False则是正式环境
   # start(False)
   # start()
   
   # send_kugou_lyrics('id',0,None,True,"朵","赵雷")
   # sync_play_state(True,0)