import json

class StandardLyrics:
    def __init__(self, title: str, artist: str, image:str,time:str,lyrics: list):
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.image = image
        self.time = time

    def to_dict(self):
        return {
            "title": self.title,
            "artist": self.artist,
            "time":self.time,
            "lyrics": self.lyrics,
            "image": self.image
        }
        
    def to_json(self, indent=4, ensure_ascii=False):
        """将对象转换成JSON字符串"""
        return json.dumps(self.to_dict(), indent=indent, ensure_ascii=ensure_ascii)
        
    def set_title(self,title):
        self.title= title
        
    def set_time(self,time):
        self.time= time

    def set_artist(self,artist):
        self.artist= artist
        
    def set_image(self,image):
        self.image= image
        