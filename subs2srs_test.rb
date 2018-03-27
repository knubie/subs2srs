require_relative 'subs2srs'
require 'test/unit'

class TestLine < Test::Unit::TestCase
  def test_if_dialogue
    line1 = "Dialogue: 0,0:00:06.27,0:00:08.63,Default,YUKKO,0000,0000,0000,,I don't have the motivation to do anything."
    line2 = "Style: ShinoLabs,Chinacat,35,&H00FFFFFF,&H000000FF,&H00616161,&H00000000,0,0,0,0,100,100,0,0,1,2.5,0,2,30,30,20,1"
    assert_equal(true, Line.new(line1).dialogue?)
    assert_equal(false, Line.new(line2).dialogue?)
  end

  def test_text_extraction
    line1 = "Dialogue: 0,0:00:03.44,0:00:08.42,Title1A,TEXT,0000,0000,0000,,{\fad(600,788)}Motivation"
    line2 = "Dialogue: 0,0:00:04.62,0:00:06.27,Default,MIO,0000,0000,0000,,What's wrong, Yukko? {D: I assume that her friend is using the nickname rather than Yuuko, which as I understand it should be her actual name? Maybe?}"
    line3 = "Dialogue: 0,0:22:10.83,0:22:16.90,ed kara,,0000,0000,0000,,{\fad(200,200)}今日もたくさん　笑ったな　たくさん　ときめいたな"
    text1 = "Motivation"
    text2 = "What's wrong, Yukko? {D: I assume that her friend is using the nickname rather than Yuuko, which as I understand it should be her actual name? Maybe?}"
    text3 = "今日もたくさん　笑ったな　たくさん　ときめいたな"
    assert_equal(text1, Line.new(line1).text)
    assert_equal(text2, Line.new(line2).text)
    assert_equal(text3, Line.new(line3).text)
  end

  def test_newline_removal
    line1 = "Dialogue: 0,0:12:07.01,0:12:12.37,Default,YUKKO,0000,0000,0000,,あのさ、\N校長って自分のギャグが古過ぎること気付いてないのかな？"
    text1 = "あのさ、校長って自分のギャグが古過ぎること気付いてないのかな？"
    assert_equal(text1, Line.new(line1).text)
  end

  def test_timestamps
    # TODO
  end

  def test_duration
    line1 = "Dialogue: 0,0:22:10.83,0:22:16.90,ed kara,,0000,0000,0000,,{\fad(200,200)}今日もたくさん　笑ったな　たくさん　ときめいたな"
    line2 = "Dialogue: 0,0:18:20.12,0:18:24.80,Default,SHINIGAMI,0000,0000,0000,,すいません！　ＫＹについて教えてくださ～い！"
    line3 = "Dialogue: 0,0:18:59.46,0:19:00.32,Default,SASAHARA,0000,0000,0000,,富岡…"
    # Buffer is 0.2s
    assert_equal('06.27', Line.new(line1).duration)
    assert_equal('04.88', Line.new(line2).duration)
    assert_equal('01.06', Line.new(line3).duration)
  end

  def test_midpoint
    line2 = "Dialogue: 0,0:18:20.12,0:18:24.80,Default,SHINIGAMI,0000,0000,0000,,すいません！　ＫＹについて教えてくださ～い！"
    assert_equal("00:18:22.560", Line.new(line2).midpoint.to_s)
  end

  def test_start_adjusted
    # TODO:
  end
end

class TestTimeStamp < Test::Unit::TestCase
  def test_init
    time_str = "0:18:20.12"
    assert_equal(Time.new(0,nil,nil,0,18,20.12), TimeStamp.new(time_str))
  end

  def test_to_s
    timestamp = TimeStamp.new("0:43:38.09")
    assert_equal("00:43:38.090", timestamp.to_s)
  end
end
