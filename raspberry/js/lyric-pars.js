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
      const { id='',title = '', artist = '', status = '', time = 0, lyrics = [] } = json;
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
  