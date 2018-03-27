class Line
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

  BUFFER = 0.2

  # Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
  LINE_REGEX = /(.*),(\d+:\d+:\d+\.*\d*),(\d+:\d+:\d+\.*\d*),(.*),(.*),(\d+),(\d+),(\d{4}),,({.*})?(.*)/

  attr_reader :start, :start_adjusted, :text

  def initialize(line, delay = 0.900)
    match = LINE_REGEX.match line
    return if match.nil?

    @layer = match[FORMAT[:layer]]
    @style = match[FORMAT[:style]]
    return unless dialogue?

    @start          = TimeStamp.new match[FORMAT[:start]]
    @end            = TimeStamp.new match[FORMAT[:end]]
    @start_adjusted = TimeStamp.new(@start + delay)
    @text           = format_text(match[FORMAT[:text]])
  end

  def dialogue?
    !!(/Dialogue/ =~ @layer) && @style == 'Default'
  end

  def nil?
    !dialogue? || !default_style?
  end

  def duration_number
    @duration_number ||= ((@end - @start) + BUFFER).round(2)
  end

  def duration
    "%05.2f" % duration_number
  end

  def midpoint
    TimeStamp.new(@start + (duration_number / 2))
  end

  private

  def format_text(text)
    text.gsub(/\N/, '')
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

class TimeStamp < BasicObject
  attr_reader :time

  def initialize(timestamp)
    @time = timestamp and return if timestamp.class.name == 'Time'
    match  = /(\d+):(\d+):(\d+\.*\d*)/.match timestamp
    hour   = match[1].to_i
    minute = match[2].to_i
    second = match[3].to_f
    @time  = ::Time.new(0, nil, nil, hour, minute, second)
  end

  def to_s
    @time.strftime("%H:%M:%S.%L")
  end

  def -(timestamp)
    return @time - timestamp if timestamp.class.name == 'Float'
    @time - timestamp.time
  end

  def method_missing(name, *args, &block)
   @time.send(name, *args, &block)
  end
end

def extract_audio(start, duration, filename, midpoint)
  #puts "ffmpeg -i nichijou-01.mkv -ss #{start} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3"
  #system "ffmpeg -i nichijou-01.mkv -ss #{start} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3"
  #puts "ffmpeg -ss #{midpoint} -i #{filename} -vframes 1 -q:v 2 #{filename}.jpg"
  #system "ffmpeg -ss #{midpoint} -i nichijou-01.mkv -vframes 1 -q:v 2 #{filename}.jpg"
end


# Japanese; Media; English
#seperator = "	"
#seperator = ";"

#sound = "[sound:#{line.text}.mp3];"

counter = 0
output = File.open( "nichijou-01.txt","w"  )

jp_lines = File.open('nichijou-01.jp.ass').map {|l| Line.new(l)}.select(&:dialogue?).map(&:text)
en_lines = File.open('nichijou-01.en.ass').map {|l| Line.new(l)}.select(&:dialogue?).map(&:text)

#en_lines2 = en_lines.each_with_index.map { |line, i|
  #if i == 19
    #puts line
    #puts en_lines[i + 1]
    #puts [en_lines[i], en_lines[i+1]].join(' ')
    #puts "#{line} #{en_lines[i +1]}"
    #"#{line} #{en_lines[i +1]}"
  #elsif i == 20
    #nil
  #else
    #line
  #end
#}.compact

#jp_lines.each_with_index do |jp_line, i|
  #if i < 3
    #puts "#{i} - #{jp_line}"
    #puts "#{i} - #{en_lines2[i]}"
    #puts '===================================================='
  #end
#end

#puts jp_lines.size
#puts en_lines.size

File.open('nichijou-01.jp.ass').map {|l| Line.new(l)}.compact.each do |line|
  if line.dialogue?
    #puts "Extracting audio for #{line.text}"
    #line.extract_audio('hichijou-01.mkv', counter)
    #extract_audio(line.start_adjusted.to_s, line.duration, "#{counter}-#{line.text}", line.midpoint.to_s)
    output << "#{line.text};[sound:#{counter}-#{line.text}.mp3];#{counter}-#{line.text}.jpg;;\n"
    counter = counter + 1
  end
end
output.close
