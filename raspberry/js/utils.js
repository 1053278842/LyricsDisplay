const Utils = {
    mod(n, m) {
      return ((n % m) + m) % m;
    },

    formatMs(ms) {
      const totalSeconds = Math.floor(ms / 1000);
      const minutes = Math.floor(totalSeconds / 60);
      const seconds = totalSeconds % 60;
      const hundredths = Math.floor((ms % 1000) / 10); // 百分之一秒（两位小数）
    
      const pad = (n, len = 2) => String(n).padStart(len, '0');
    
      return `[${pad(minutes)}:${pad(seconds)}.${pad(hundredths)}]`;
    }
    
};