require 'irb'
require 'optparse'
require 'zip'
require_relative 'string_ext'

$stdout.sync = true

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

  opts.on("--[no-]audio", "Don't save audio") do |b|
    $options[:audio] = b
  end

  opts.on("--skip-to N", Integer, "Skip to the Nths line of dialogue before capturing") do |n|
    $options[:skip_to] =n
  end
end.parse!

require_relative 'lib/subtitle_line'

#puts $options
#puts ARGV


video_title     = video_file.split('.').first
subtitle_format = subtitle_file.split('.').last


def extract_audio(start, duration, filename, midpoint, video_file)
  # https://trac.ffmpeg.org/wiki/Seeking#Cuttingsmallsections
  if $options[:audio]
    #puts   "Extracting audio for line"
    #puts   "ffmpeg -ss #{start}  -i #{video_file} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3"
    system "ffmpeg -ss #{start}  -i #{video_file} -t 00:00:#{duration} -q:a 0 -map a #{filename}.mp3 >/dev/null 2>&1"
  end

  if $options[:images]
    #puts   "Extracting image for line"
    #puts   "ffmpeg -ss #{midpoint} -i #{video_file} -vframes:v 1 -q:v 2 #{filename}.jpg"
    #system "ffmpeg -ss #{midpoint} -i #{video_file} -filter:v -frames:v 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
    system "ffmpeg -ss #{midpoint} -i #{video_file} -frames:v 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
    # TODO: Crop option.
    #system "ffmpeg -ss #{midpoint} -i #{video_file} -filter:v \"crop=in_w:in_h-170:0:0\" -vframes 1 -q:v 2 #{filename}.jpg >/dev/null 2>&1"
  end
end

class LineCollection
  attr_accessor :lines

  def initialize(video_title, video_file)
    @video_title = video_title
    @video_file = video_file
    @lines = []
  end

  def make_cards!
    counter = $options[:skip_to] || 0
    output = File.open( "#{@video_title}.txt","w"  )
    limit = $options[:limit]

    @lines.each do |line|
      if limit.nil? || (limit && counter <= limit)

        extract_audio(
          line.start_adjusted.to_s,
          line.duration,
          "#{@video_title}-#{counter}",
          line.midpoint.to_s,
          @video_file
        )

        output << <<-CARD
          {:sort #{counter}
           :fields {:japanese "#{line.text}"
                    :english ""
                    :audio "#{@video_title}-#{counter}.mp3"
                    :screenshot "#{@video_title}-#{counter}.jpg"}}
        CARD
      end
      counter = counter + 1
    end

    output.close
  end
end


if subtitle_format == 'vtt' || subtitle_format == 'srt'
  TIMESTAMP_REGEX = /(\d{2}:\d{2}:\d{2}[.|,]\d{3}) --> (\d{2}:\d{2}:\d{2}[.|,]\d{3})/
  NEWLINE_REGEX = /^\n$/ 
  COUNTER_REGEX = /^\d+$/ 

  line_collection = LineCollection.new(video_title, video_file)
  line_count = 0
  skip_to = $options[:skip_to] || 0

  File.open(subtitle_file).each do |line|
    #line_count = line_count + 1
    next if NEWLINE_REGEX.match line # Skip newlines
    if COUNTER_REGEX.match line
      line_count = line.to_i - 1
      next
    end # Skip the counters in SRT files
    next if line_count < skip_to
    match = TIMESTAMP_REGEX.match line # Start of a line
    if match
      line_collection.lines << VTTLine.new(match)
    else
      line_collection.lines.last.dialogue << line
    end
  end

  line_collection.make_cards!
end



# Japanese; Media; English
#seperator = "	"
#seperator = ";"

#sound = "[sound:#{line.text}.mp3];"

# List of media files to be zipped up later.
media_files = ['data.edn']

if subtitle_format == 'ass'
  counter = 0
  limit = $options[:limit]
  output = File.open( "#{video_title}.edn","w"  )
  cards = ""



  File.open(subtitle_file).map { |l| ASSLine.new(l)}.compact.each do |line|
    #puts line.dialogue? ? "not dialogue" : "is dialogue"
    # TODO: Multithreading
    if line.dialogue? && line.real?
      if (limit && counter <= limit) || limit.nil? 

        printf "Extracting: %-80s\r", line.text
        #printf("\rExtracting: %d%", line.text)

        extract_audio(line.start_adjusted.to_s, line.duration, "#{video_title}-#{counter}", line.midpoint.to_s, video_file)
        line_text = line.text

        # Add file names to list of files to be zipped later.
        media_files << "#{video_title}-#{counter}.mp3"
        media_files << "#{video_title}-#{counter}.jpg"

        audio = "@media/#{video_title}-#{counter}.mp3" 
        screenshot = "#{video_title}-#{counter}.jpg"
        screenshot_src = "@media/#{video_title}-#{counter}.jpg"

        content = <<~CONTENT
          ![#{screenshot}](#{screenshot_src})
          ![](#{audio})
          ---
          #{line_text}
        CONTENT

        cards << <<~CARD
          {:content "#{content}"
           :sort #{counter}}
        CARD
      end
      counter = counter + 1
    end
  end

  output << <<~DECK
    {:name "#{video_title}"
      :cards [
        #{cards}
      ]
    }
  DECK

  output.close
end

folder = "./output"
input_file_names = ['data.edn']

