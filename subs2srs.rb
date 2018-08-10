require 'irb'
require 'optparse'

#TODO: Add options to only regenerate text, images or audio
video_file = ARGV[0]
raise "Video file required." unless video_file

subtitle_file = ARGV[1]
raise "Subtitle file required." unless subtitle_file

#raise "Too many arguments." if ARGV.size > 2

$options = {images: true, audio: true}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("--buffer N", Float, "The buffer (in milliseconds) around each audio clip") do |n|
    $options[:buffer] = n
  end

  opts.on("--delay N", Float, "The delay added to (or subtracted from) the start of the timestamp") do |n|
    $options[:delay] = n
  end

  opts.on("--limit N", Integer, "Limit the number of lines of dialogue captured") do |n|
    $options[:limit] = n
  end

  opts.on("--[no-]images", "Don't save screenshots") do |b|
    $options[:images] = b
  end

  opts.on("--no-audio", "Don't save audio") do |b|
    $options[:no_audio] = b
  end
end.parse!

puts $options
puts ARGV

class SubtitleLine
  attr_reader :start, :start_adjusted, :text

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
    puts (!dialogue? || !real?)
    !dialogue? || !real?
  end

  private

  def format_text(text)
    text.strip
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
    # time format -> "00:00:06.400 --> 00:00:12.180"
    @start          = TimeStamp.new time[1]
    @end            = TimeStamp.new time[2]
    @start_adjusted = TimeStamp.new(@start + DELAY)
    @dialogue = []
  end

  def text
    @dialogue.join('　').strip
  end
end

class TimeStamp < BasicObject
  attr_reader :time

  def initialize(timestamp)
    # timestamp format -> 00:00:00.00
    @timestamp = timestamp
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

#video_file      = 'おむすびころりん.mkv' 
video_title     = video_file.split('.').first
subtitle_format = subtitle_file.split('.').last


def extract_audio(start, duration, filename, midpoint, video_file)
  # https://trac.ffmpeg.org/wiki/Seeking#Cuttingsmallsections
  unless $options[:no_audio]
    puts   "Extracting audio for line"
    puts   "ffmpeg -ss #{start}  -i #{video_file} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3"
    system "ffmpeg -ss #{start}  -i #{video_file} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3 >/dev/null 2>&1"
  end

  if $options[:images]
    puts   "Extracting image for line"
    puts   "ffmpeg -ss #{midpoint} -i #{video_file} -vframes:v 1 -q:v 2 #{filename}.jpg"
    #system "ffmpeg -ss #{midpoint} -i #{video_file} -filter:v -frames:v 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
    system "ffmpeg -ss #{midpoint} -i #{video_file} -frames:v 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
    # TODO: Crop option.
    #system "ffmpeg -ss #{midpoint} -i #{video_file} -filter:v \"crop=in_w:in_h-170:0:0\" -vframes 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
  end
end


if subtitle_format == 'vtt'
  VTT_REGEX = /(\d{2}:\d{2}:\d{2}\.\d{3}) --> (\d{2}:\d{2}:\d{2}\.\d{3})/
  lines = []
  line_count = 0
  File.open(subtitle_file).each do |line|
    line_count = line_count + 1
    next if /^\n$/.match line # Skip newlines
    next if line_count < 5    # Skip the first 5 lines
    match = VTT_REGEX.match line
    if match
      lines << VTTLine.new(match)
    else
      lines.last.dialogue << line
    end
  end

  counter = 0
  output = File.open( "#{video_title}.txt","w"  )

  lines.each do |line|
    #extract_audio(line.start_adjusted.to_s, line.duration, "#{video_title}-#{counter}", line.midpoint.to_s, video_file)
    #output << "#{line.text};[sound:#{video_title}-#{counter}.mp3];#{video_title}-#{counter}.jpg;;\n"
    output << <<-CARD
      {:fields {:japanese "#{line.text}"
                :english ""
                :audio "#{video_title}-#{counter}.mp3"
                :screenshot "#{video_title}-#{counter}.jpg"}}

    CARD
    counter = counter + 1
  end

  output.close
end


# Japanese; Media; English
#seperator = "	"
#seperator = ";"

#sound = "[sound:#{line.text}.mp3];"

if subtitle_format == 'ass'
  counter = 0
  limit = $options[:limit]
  output = File.open( "#{video_title}.txt","w"  )

  #jp_lines = File.open('nichijou-01.jp.ass').map {|l| Line.new(l)}.select(&:dialogue?).map(&:text)
  #en_lines = File.open('nichijou-01.en.ass').map {|l| Line.new(l)}.select(&:dialogue?).map(&:text)

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

  # TODO: Escape \N and "
  File.open(subtitle_file).map { |l| ASSLine.new(l)}.compact.each do |line|
    #puts line.dialogue? ? "not dialogue" : "is dialogue"
    # TODO: Multithreading
    if line.dialogue? && line.real?
      # counter == 35 # TODO: make this user input
      #if counter == 203
      if (limit && counter <= limit) || limit.nil? 
        extract_audio(line.start_adjusted.to_s, line.duration, "#{video_title}-#{counter}", line.midpoint.to_s, video_file)
        # Line 38 is a problem
        output << <<-CARD
          {:sort #{counter}
           :fields {:japanese "#{line.text.gsub('"', '\"')}"
                    :english ""
                    :audio "#{video_title}-#{counter}.mp3"
                    :screenshot "#{video_title}-#{counter}.jpg"}}
        CARD
      end
      counter = counter + 1
    end
  end
  output.close
end
