# Ruby Subs 2 SRS

This script will convert a video file + subtitle file to `.mochi` deck for usage in [Mochi](https://mochi.cards/).

Works with `.srt`, `.vtt`, and `.ass` subtitle files.

### Dependencies

Gem dependencies are managed with bundler.
```
$ bundle install
```

This script also depends on ffmpeg, you can install it using [Homebrew](https://brew.sh)
```
$ brew install ffmpeg
```

### Usage
```
$ ruby subs2srs.rb my_video_file.mp4 my_subtitle_file.srt [options]
```

Use:
```
$ ruby subs2srs.rb --help
```
for more options.
