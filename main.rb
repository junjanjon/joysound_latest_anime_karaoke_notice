require 'date'
require 'json'
require 'digest/md5'
require 'net/http'
require 'yaml'
require 'twitter'

class SimpleHistoryCheck
  HISTORY_FILE = 'history.txt'.freeze

  attr_accessor :use_md5

  def initialize(use_md5 = false)
    @lines = []
    @use_md5 = use_md5
    return unless File.exist?(HISTORY_FILE)
    file = File.read(HISTORY_FILE)
    @lines = file.each_line.map(&:chomp)
  end

  def had_history(log_line)
    log_line = Digest::MD5.hexdigest(log_line) if @use_md5
    !@lines.index(log_line).nil?
  end

  def register_history(log_line)
    log_line = Digest::MD5.hexdigest(log_line) if @use_md5
    File.open(HISTORY_FILE, 'a') do |f|
      f.puts log_line
    end
  end
end

class SearchRequestParameter
  attr_accessor :word1, :word2

  def initialize
    @word1 = '10000002'
    @word2 = '0'
  end

  def from_text
    from = (Date.today - 15)
    from.strftime('%Y%m%d000000')
  end

  def to_text
    to = (Date.today + 15)
    to.strftime('%Y%m%d000000')
  end

  def params
    data = [
      'start=1&',
      'count=50&',
      "serviceStartDateFrom=#{from_text}&",
      "serviceStartDateTo=#{to_text}&",
      "word1=#{@word1}&",
      'kind1=selGenre&match1=exact&',
      "word2=#{@word2}&",
      'kind2=selArrange&match2=exact&',
      'format=all&kindCnt=2&order=desc&sort=ServicePublishDate&',
      'apiVer=1.0'
    ].join('').split('&').map { |d| { d.split('=')[0] => d.split('=')[1] } }

    data.inject({}) { |p, d| p.merge(d) }
  end
end

def request_new_list(params)
  uri = URI.parse('https://mspxy.joysound.com/Common/ContentsList')
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  # https.set_debug_output($stderr)

  req = Net::HTTP::Post.new(uri.request_uri)
  req.set_form_data(params, '&')
  req['x-jsp-app-name'] = '0000800'
  req['accept'] = 'application/json'
  req['User-Agent'] = 'Ruby'
  res = https.request(req)

  # puts "code -> #{res.code}"
  # puts "msg -> #{res.message}"
  # puts "body -> #{res.body}"

  res.body
end

class ContentsList
  def initialize(response)
    @response = response
    @json = JSON.parse(@response)
    @contents_list = @json['contentsList']
  end

  def info_list
    @contents_list.map do |content|
      c = Content.new(content)
      no_tieup_message =
        "「#{c.song_name}」 が #{c.formated_service_publish_date} 配信です。\n" +
        "歌手名: #{c.artistName}  作詞: #{c.lyricist}"
      next "#{c.tieup_name} の #{no_tieup_message}" unless c.tieup_name.nil?
      no_tieup_message
    end
  end

  class Content
    def initialize(content)
      @content = content
    end

    def song_name
      @content['songName']
    end

    def tieup_name
      @content['tieupList'][0]['tieupName'] unless @content['tieupList'].empty?
    end

    def lyricist
      @content['lyricist']
    end

    def artistName
      @content['artistName']
    end

    def formated_service_publish_date
      date = @content['serviceTypeList'][0]['ServicePublishDate']
      Date.parse(date).strftime('%Y/%m/%d')
    end
  end
end

class TwitterStub
  def update(message) 
    puts "====TwitterStub START===="
    puts "#{message}"
    puts "====TwitterStub END===="
  end
end

def get_twitter_client
  # return TwitterStub.new
  config_yaml = YAML.load_file('twitter_config.yml')
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = config_yaml['consumer_key']
    config.consumer_secret     = config_yaml['consumer_secret']
    config.access_token        = config_yaml['access_token']
    config.access_token_secret = config_yaml['access_token_secret']
  end
end

def work(twitter_client, word2, message_head)
  history = SimpleHistoryCheck.new(true)

  request = SearchRequestParameter.new
  request.word2 = word2
  response = request_new_list(request.params)
  info_list = ContentsList.new(response).info_list
  new_info = info_list.reject { |o| history.had_history(o) }

  unless new_info.empty?
    new_info.each do |info|
      message = message_head +
          info + "\n" +
          '#ジョイサウンド #アニメカラオケ'

      message = message[0, 135] + '...' if 140 < message.length
      puts message
      twitter_client.update(message)
      history.register_history(info)
      sleep(5)
    end
    sleep(5)
  end
rescue StandardError => e
  p e
end

def main
  twitter_client = get_twitter_client
  work(twitter_client, '0', '')
  work(twitter_client, '2,8', '〜映像付き！〜' + " #アニメ映像付きカラオケ \n")
end

main