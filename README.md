# LyricsDisplay
获取各类APP中运行的歌词，同步到树莓派中进行展示

## 如何使用
1. 集成到安卓项目:

    入口方法为main方法。

    ```java
    @Override
    public void sendSongInfo(String id, long position, String image, boolean status, String title, String artist, long duration) {
        try {
            pyMain.callAttr("send_kugou_lyrics", id, position, image, status, title, artist, duration);
        } catch (PyException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void sendPlayState(boolean status, long position) {
        try {
            pyMain.callAttr("sync_play_state", status, position);
        } catch (PyException e) {
            e.printStackTrace();
        }
    }
    ```

2. 集成到树莓派中:

    raspberry目录下
    -- flask_app.py 是flask监听接口，需要部署到开机自启。
    -- 其他html页面 ，部署到自启网页中即可

    