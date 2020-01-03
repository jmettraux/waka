
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

    def assignments(*subject_ids)

      subject_ids = subject_ids[0] \
        if subject_ids.length == 1 && subject_ids.first.is_a?(Array)

      get(:assignments, subject_ids: subject_ids)
    end

    def reviews(*subject_ids)

      subject_ids = subject_ids[0] \
        if subject_ids.length == 1 && subject_ids.first.is_a?(Array)

      get(:reviews, subject_ids: subject_ids)
    end

    def rstatistics(*subject_ids)

      subject_ids = subject_ids[0] \
        if subject_ids.length == 1 && subject_ids.first.is_a?(Array)

      get(:review_statistics, subject_ids: subject_ids)
    end

    def lprogressions

      get(:level_progressions)
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
        current_level = session.lprogressions['total_count']

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

        subject_ids = subject_ids.to_a[0, 1000]

        subjects =
          session.subjects(subject_ids)['data']
            .inject({}) { |h, o|
              begin
                d = o['data']
                h[o['id']] =
                  { i: o['id'],
                    l: d['level'],
                    cl: d['level'] == current_level,
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

        session.assignments(subject_ids)['data']
          .each { |a|

            d = a['data']

            ss = d['srs_stage']
            ssn = d['srs_stage_name']
            next unless ssn
            ssi = ssn[0, 1] + ss.to_s
            ssi = ssi.downcase if ssn.match(/^A/)

            subjects[d['subject_id']].merge!({ ss: ss, ssn: ssn, ssi: ssi }) }

        session.rstatistics(subject_ids)['data']
          .each { |a|
            d = a['data']
            subjects[d['subject_id']]
              .merge!({
                mc: d['meaning_correct'], mi: d['meaning_incorrect'],
                mms: d['meaning_max_streak'], mcs: d['meaning_current_streak'],
                rc: d['reading_correct'], ri: d['reading_incorrect'],
                rms: d['reading_max_streak'], rcs: d['reading_current_streak'],
                pc: d['percentage_correct'] }) }

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

      class Html
        def initialize(tagname, args, &block)
          @tagname = tagname
          @attributes = args.find { |a| a.is_a?(Hash) } || {}
          @children = []
          @text =
            if block
              r = instance_eval(&block)
              r.is_a?(Html) ? nil : r.to_s
            else
              r = args.find { |a| ! a.is_a?(Hash) }
              r != nil ? r.to_s : nil
            end
        end
        def method_missing(m, *args, &block)
#p m
          @children << Html.new(m, args, &block)
        end
        def to_s
          atts = @attributes
            .map { |k, v|
              v.is_a?(Array) ?
              "#{k}=#{v.collect(&:to_s).join(' ').inspect}" :
              "#{k}=#{v.to_s.inspect}" }
            .join(' ')
          atts =
            ' ' + atts if @attributes.any?
          s = "<#{@tagname}#{atts}>"
          if @children.any?
            s += "\n"
            s += @children.collect(&:to_s).join
          elsif @text
            s += @text
          else
            # nada
          end
          s += "</#{@tagname}>\n"
          s
        end
        def self.generate(&block)
          Html.new(:html, {}, &block)
        end
      end

      def upcoming_html(*types)

        types = %w[ r k t ] if types.empty?
        types = types.collect(&:to_s)

        count = 0
        u = upcoming

        puts Html.generate {
          head do
            meta charset: 'UTF-8'
            title "WK Upcoming - #{u.first[0].strftime('%F %R')}"
            link href: 'https://fonts.googleapis.com/css?family=Kosugi+Maru&display=swap', rel: 'stylesheet'
            style do
              File.read(File.join(File.dirname(__FILE__), 'upcoming.css'))
            end
          end
          body do
            table class: 'upcoming' do
              u.each do |time, subjects|
                tr class: 'time' do
                  td colspan: 3
                  td class: 'time', colspan: 4 do time.strftime('%F %R') end
                  td class: 'count', colspan: 1 do
                    span class: 'size' do subjects.size end
                    span class: 'count' do count += subjects.size end
                  end
                end
                subjects.each do |s|
                  tr class: [ s[:o], s[:l], s[:ssi] ] do
                    td class: 'id' do s[:i] end
                    td class: 'type' do s[:o] end
                    td class: [ 'level', s[:cl] ? 'current' : '' ] do s[:l] end
                    td class: 'text' do
                      if s[:o] == 'k'
                        a href: "https://www.wanikani.com/kanji/#{s[:t]}", target: '_blank' do
                          s[:t]
                        end
                      else
                        s[:t]
                      end
                    end
                    td class: 'srs' do s[:ssi] end
                    td class: 'pc' do "#{s[:pc]}%" end
                    td class: 'readings' do (s[:rs] || []).join(', ') end
                    td class: 'meanings' do (s[:ms] || []).join(', ') end
                  end
                end
              end
            end
            script do
              File.read(File.join(File.dirname(__FILE__), 'h-1.2.0.min.js'))
            end
            script do
              File.read(File.join(File.dirname(__FILE__), 'upcoming.js'))
            end
          end
        }.to_s
      end
    end
  end
end

