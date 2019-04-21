class SubtitleLine
  attr_reader :start, :start_adjusted, :end_adjusted, :text

  BUFFER = $options[:buffer] || 0.1

  def duration_number
    @duration_number ||= ((@end - @start) + BUFFER).round(2)
  end

  def duration
    "%05.2f" % duration_number
  end

  def midpoint
    TimeStamp.new(@start + (duration_number / 2))
  end
end

class ASSLine < SubtitleLine
  FORMAT = {
    layer:   1,
    start:   2,
    end:     3,
    style:   4,
    name:    5,
    marginl: 6,
    marginr: 7,
    marginv: 8,
    effect:  nil,
    junk:    9,
    text:    10
  }

  DELAY = $options[:delay] || 0.000 

  # Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
  LINE_REGEX = /(.*),(\d+:\d+:\d+\.*\d*),(\d+:\d+:\d+\.*\d*),(.*),(.*),(\d+),(\d+),(\d+),,({.*})?(.*)/

  def initialize(line)
    match = LINE_REGEX.match line
    return if match.nil?

    @layer = match[FORMAT[:layer]]
    @style = match[FORMAT[:style]]
    return unless dialogue?

    @start          = TimeStamp.new match[FORMAT[:start]]
    @end            = TimeStamp.new match[FORMAT[:end]]
    @start_adjusted = TimeStamp.new(@start + DELAY)
    @end_adjusted   = TimeStamp.new(@end + DELAY)
    @text           = format_text(match[FORMAT[:text]])
  end

  def dialogue?
    # TODO: check that the @end is no 0:00:00 instead.
    !!(/Dialogue/ =~ @layer) && @style != "*Default"
      #['Default', '白熊日文'].include?(@style) # TODO: User specify style
  end

  #TODO: better name
  def real?
    !@end.zero? && !@text.empty?
  end

  def nil?
    !dialogue? || !real?
  end

  private

  def format_text(text)
    text.squish.gsub('"', '&quot;').gsub("\\", "\\\\\\\\")
  end

  #def extract_audio(video, index)
    #opts {
      #filename: "#{index}-#{text}.mp3"
      #input:    "-i #{video}"
      #start:    "-ss #{start_adjusted.to_s}"
      #duration: "-t 00:00:#{duration}"
    #}

    #system "ffmpeg #{opts.input} #{opts.start} #{opts.duration} -q:a 0 -map a #{opts.filename}"
  #end

  #def get_screenshot(video, index)
    #system "ffmpeg -ss #{midpoint} -i #{video} -vframes 1 -q:v 2 #{filename}.jpg"
  #end
end

class VTTLine < SubtitleLine
  attr_reader :start, :start_adjusted, :text
  attr_accessor :dialogue

  DELAY = $options[:delay] || 0.000 

  def initialize(time)
    # time format: "00:00:06.400 --> 00:00:12.180"
    @start          = TimeStamp.new time[1]
    @end            = TimeStamp.new time[2]
    @start_adjusted = TimeStamp.new(@start + DELAY)
    @end_adjusted   = TimeStamp.new(@end + DELAY)
    @dialogue = []
  end

  def text
    @dialogue.join(' ').squish.gsub('"', '&quot;').gsub("\\", "\\\\\\\\")
  end
end

class TimeStamp < BasicObject
  attr_reader :time

  def initialize(timestamp)
    # timestamp format -> 00:00:00.00
    # OR 00:00:00,00
    if timestamp.class.name == 'Time'
      @time = timestamp and return
    else
      @timestamp = timestamp.gsub(',', '.')
    end
    #@time = timestamp and return if timestamp.class.name == 'Time'
    match  = /(\d+):(\d+):(\d+\.*\d*)/.match @timestamp
    hour   = match[1].to_i
    minute = match[2].to_i
    second = match[3].to_f
    @time  = ::Time.new(0, nil, nil, hour, minute, second)
  end

  def to_s
    @time.strftime("%H:%M:%S.%L")
  end

  def zero?
    @timestamp == '0:00:00.00'
  end

  def -(timestamp)
    return @time - timestamp if timestamp.class.name == 'Float'
    @time - timestamp.time
  end

  def method_missing(name, *args, &block)
   @time.send(name, *args, &block)
  end
end
