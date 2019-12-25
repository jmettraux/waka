
require 'set'
require 'time'
require 'json'
require 'net/http'


module Waka

  BASE_URI = 'https://api.wanikani.com/v2/'

  class << self

    def load_token(path)

      File.read(path).strip
    end
  end

  class Session

    def initialize(path_or_token)

      @token = path_or_token
      @token = './.wanikani_api_token' if @token == '.'
      @token = File.read(@token).strip if @token.match(/\//)
    end

    def summary

      get(:summary)
    end

    def subjects(*ids)

      ids = ids[0] if ids.length == 1 && ids.first.is_a?(Array)

      get(:subjects, ids: ids)
    end

    protected

    def get(*as)

      q = {}
      q = as.pop if as.last.is_a?(Hash)

      u = BASE_URI + as.join('/')
      u += '?' + q.map { |k, v| "#{k}=#{v.map(&:to_s).join(',')}" }.join('&') \
        if q.any?
      u = URI(u)

      http = Net::HTTP.new(u.host, u.port)
      http.use_ssl = true

      req = Net::HTTP::Get.new(u.to_s)
      req.instance_eval { @header.clear }
      def req.set_header(k, v); @header[k] = [ v ]; end

      req.set_header('User-Agent', "#{self.class}")
      req.set_header('Accept', 'application/json')
      req.set_header('Authorization', "Bearer #{@token}")

      res = http.request(req)

      fail "request returned a #{res.class} and not a Net::HTTPResponse" \
        unless res.is_a?(Net::HTTPResponse)

      JSON.parse(res.body)
    end
  end

  module Reports

    class << self

      def upcoming

        session = Waka::Session.new('.')
        summary = session.summary

        subject_ids = Set.new

        reviews =
          summary['data']['reviews']
            .collect { |r|
              t = Time.parse(r['available_at']).localtime
              is = r['subject_ids']
              subject_ids.merge(is)
              [ t, is ] }
            .reject { |r|
              r[1].empty? }

        subjects =
          session.subjects(subject_ids.to_a[0, 400])['data']
            .inject({}) { |h, o|
              begin
                d = o['data']
                h[o['id']] =
                  { i: o['id'],
                    l: d['level'],
                    o: o['object'][0, 1],
                    t: d['characters'],
                    ms: d['meanings'].map { |m| m['meaning'] },
                    rs: (d['readings'].map { |r| r['reading'] } rescue nil),
                    pos: d['part_of_speech'] }
              rescue => err
                puts "..."
                pp o
                p err
              end
              h }

        reviews.each do |r|
          r[1] = r[1]
            .collect { |i| subjects[i] }
            .sort_by { |s|
              case s[:o]
              when 'r' then 0
              when 'k' then 1
              else 2
              end }
        end

        reviews
      end

      def upcoming_text(*types)

        types = %w[ r k t ] if types.empty?
        types = types.collect(&:to_s)

        puts
        upcoming[0, 3].each do |time, subjects|
          puts time
          subjects.each do |s|
            next unless types.include?(s[:o])
            printf(
              "%7d %2d %s %-9s %-12s %s\n",
              s[:i], s[:l], s[:o], s[:t],
              (s[:rs] || []).join(', '), s[:ms].join(', '))
          end
        end
        puts
      end

      def upcoming_html(*types)

        types = %w[ r k t ] if types.empty?
        types = types.collect(&:to_s)

        puts '<html>'
        puts '<head>'
        puts '<meta charset="utf-8" />'
        puts '<title>WK Upcoming</title>'
        puts '<link href="https://fonts.googleapis.com/css?family=Kosugi+Maru&display=swap" rel="stylesheet">'
        puts '<style>'
        puts File.read(File.join(File.dirname(__FILE__), 'upcoming.css')) rescue ''
        puts '</style>'
        puts '</head>'
        puts '<table>'
        upcoming.each do |time, subjects|
          puts '<tr>'
          puts '<td class="time" colspan="4">'
          puts time.to_s
          puts '</td>'
          puts '<td class="count" colspan="1">'
          puts subjects.size.to_s
          puts '</td>'
          puts '</tr>'
          subjects.each do |s|
            puts "<tr class=\"#{s[:o]}\">"
            puts '<td class="id">'
            puts s[:i]
            puts '</td>'
            puts '<td class="level">'
            puts s[:l]
            puts '</td>'
            puts '<td class="text">'
            puts s[:t]
            puts '</td>'
            puts '<td class="readings">'
            puts (s[:rs] || []).join(', ')
            puts '</td>'
            puts '<td class="meanings">'
            puts s[:ms].join(', ')
            puts '</td>'
            puts '</tr>'
          end
        end
        puts '</table>'
        puts '<body>'
        puts '</body>'
        puts '</html>'
      end
    end
  end
end

