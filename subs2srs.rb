require 'irb'
require 'optparse'
require 'zip'
require_relative 'string_ext'

$stdout.sync = true

$options = {images: true, audio: true}

OptionParser.new do |opts|
  opts.banner = "Usage: example.rb video_file subtitle_file [options]"

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

  opts.on("--[no-]audio", "Don't save audio") do |b|
    $options[:audio] = b
  end

  opts.on("--skip-to N", Integer, "Skip to the Nths line of dialogue before capturing") do |n|
    $options[:skip_to] =n
  end

  opts.on("--video", "Embed video instead of audo + screenshots") do |b|
    $options[:video] = b
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

#TODO: Add options to only regenerate text, images or audio
video_file = ARGV[0]
raise "Video file required." unless video_file

subtitle_file = ARGV[1]
raise "Subtitle file required." unless subtitle_file

#raise "Too many arguments." if ARGV.size > 2

require_relative 'lib/subtitle_line'
require_relative 'lib/av'


video_title     = video_file.split('.').first
subtitle_format = subtitle_file.split('.').last

EDN_FILE_NAME = 'data.edn'

# List of media files to be zipped up later.
media_files = [EDN_FILE_NAME]

class LineCollection
  attr_accessor :lines

  def initialize(video_title, video_file)
    @video_title = video_title
    @video_file = video_file
    @lines = []

    @cards_edn = ""
    @media_files = [EDN_FILE_NAME]
  end

  def make_cards!
    counter = $options[:skip_to] || 0
    output = File.open(EDN_FILE_NAME, "w")

    limit = $options[:limit]

    @lines.each do |line|
      if limit.nil? || (counter <= limit)

        extract_media!(line, counter)

        @cards_edn << card_edn(line, counter)

        add_media_files! counter
      end
      counter = counter + 1
    end

    output << deck_edn
    output.close

    Zip::File.open("#{@video_title}.mochi", Zip::File::CREATE) do |zipfile|
      @media_files.each do |filename|
        zipfile.add(filename, File.join(".", filename))
      end
    end
  end

  private

  def extract_media!(line, counter)
    printf "Extracting: %-80s\r", line.text

    AV.extract_media(
      start:      line.start_adjusted.to_s,
      duration:   line.duration,
      filename:   "#{@video_title}-#{counter}",
      midpoint:   line.midpoint.to_s,
      video_file: @video_file
    )
  end

  def add_media_files!(counter)
    # Add file names to list of files to be zipped later.
    if $options[:audio]
      @media_files << "#{@video_title}-#{counter}.mp3"
    end

    if $options[:images]
      @media_files << "#{@video_title}-#{counter}.jpg"
    end
  end

  def deck_edn
    <<~DECK
      {:name "#{@video_title}"
        :cards [
          #{@cards_edn}
        ]
      }
    DECK
  end

  def card_edn(line, counter)
    audio = "@media/#{@video_title}-#{counter}.mp3" 
    screenshot = "#{@video_title}-#{counter}.jpg"
    screenshot_src = "@media/#{@video_title}-#{counter}.jpg"

    content = <<~CONTENT
      ![#{screenshot}](#{screenshot_src})
      ![](#{audio})
      ---
      #{line.text}
    CONTENT

    <<~CARD
      {:content "#{content}"
       :sort #{counter}}
    CARD
  end
end

class VideoLineCollection < LineCollection
  def initialize(*args)
    super *args
    @media_files << @video_file
  end

  def extract_media! *args; end

  def add_media_files! *args; end

  private

  def card_edn(line, counter)
    content = <<~CONTENT
      ![#{@video_title}](@media/#{@video_file}#t=#{line.start_adjusted.to_s},#{line.end_adjusted.to_s})
      ---
      #{line.text}
    CONTENT

    <<~CARD
      {:content "#{content}"
       :sort #{counter}}
    CARD
  end
end


if subtitle_format == 'vtt' || subtitle_format == 'srt'
  TIMESTAMP_REGEX = /(\d{2}:\d{2}:\d{2}[.|,]\d{3}) --> (\d{2}:\d{2}:\d{2}[.|,]\d{3})/
  NEWLINE_REGEX = /^\n$/ 
  COUNTER_REGEX = /^\d+$/ 

  if $options[:video]
    line_collection = VideoLineCollection.new(video_title, video_file)
  else
    line_collection = LineCollection.new(video_title, video_file)
  end

  line_count = 0
  skip_to = $options[:skip_to] || 0

  File.open(subtitle_file).each do |line|

    next if line_count < skip_to

    line = line.strip

    #line_count = line_count + 1
    next if line == "" # Skip newlines

    next if /.*SKIP/.match line

    if COUNTER_REGEX.match line.strip
      line_count = line.to_i - 1
      next
    end # Skip the counters in SRT files

    match = TIMESTAMP_REGEX.match line.strip # Start of a line
    if match
      line_collection.lines << VTTLine.new(match)
    else
      line_collection.lines.last.dialogue << line.strip
    end
  end

  line_collection.make_cards!
end


if subtitle_format == 'ass'
  if $options[:video]
    line_collection = VideoLineCollection.new(video_title, video_file)
  else
    line_collection = LineCollection.new(video_title, video_file)
  end

  File.open(subtitle_file).map { |l| ASSLine.new(l)}.compact.each do |line|
    #puts line.dialogue? ? "not dialogue" : "is dialogue"
    # TODO: Multithreading
    if line.dialogue? && line.real?
      line_collection.lines << line
    end
  end


  line_collection.make_cards!
end
