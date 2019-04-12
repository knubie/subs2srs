class AV
  # https://trac.ffmpeg.org/wiki/Seeking#Cuttingsmallsections
  def self.extract_media(start:, duration:, filename:, midpoint:, video_file:)
    if $options[:audio]
      system "ffmpeg -ss #{start}  -i #{video_file} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3 >/dev/null 2>&1"
    end

    if $options[:images]
      system "ffmpeg -ss #{midpoint} -i #{video_file} -frames:v 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
      # TODO: Crop option.
    end
  end
end
