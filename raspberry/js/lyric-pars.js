const LyricInfo = {
    id:'',
    title: '',
    artist: '',
    status: '',
    time: 0,
    lyrics:[],
    currentLyricIndex: 0,
    interval: 0
  };
  
  const LyricState = {
    data: { ...LyricInfo },
  
    update(json) {
      var { id='',title = '', artist = '', status = '', time = 0, lyrics = [] } = json;
      if(lyrics == null && id == null &&time != null && status !=null){
        //说明当前传递的仅仅是状态
        id = this.data.id;  
        title = this.data.title;
        artist = this.data.artist;
        lyrics = this.data.lyrics;
      }
      let currentLyricIndex = 0;
      let interval = 0;
  
      for (let i = 0; i < lyrics.length; i++) {
        if (lyrics[i].startTimeMs >= time) {
          currentLyricIndex = i;
          interval = lyrics[i].startTimeMs - time;
          break;
        }
      }
  
      this.data = {
        id,
        title,
        artist,
        status,
        time,
        currentLyricIndex,
        interval,
        lyrics
      };
    },
  
    get() {
      return this.data;
    }
  };
  