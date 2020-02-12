
require 'set'
require 'time'
require 'json'
require 'net/http'


module Waka

  WWW_URI =
    'https://www.wanikani.com/'
  API_URI =
    'https://api.wanikani.com/v2/'
  FONT_HREF =
    'https://fonts.googleapis.com/css?family=Kosugi|Kosugi+Maru&display=swap'

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

      query =
        if subject_ids.first.is_a?(Hash)
          subject_ids[0]
        else
          { subject_ids: subject_ids[0] }
        end

      get(:assignments, query)
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

    def level_krs(level)

      get(:subjects, types: %w[ kanji radical ], levels: [ level ])['data']
        .collect { |s| { sid: s['id'], o: s['object'][0, 1] } }
    end

    protected

    def get(*as)

      q = {}
      q = as.pop if as.last.is_a?(Hash)

      u = API_URI + as.join('/')
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

      def apprentice

        session = Waka::Session.new('.')

        subjects = {}

        apprentices = session
          .assignments(
            srs_stages: [ 1, 2, 3, 4 ] + [ 5 ],
            subject_types: %w[ radical kanji ])

        merge!(subjects, apprentices)
        merge!(subjects, session.subjects(subjects.keys))
        merge!(subjects, session.rstatistics(subjects.keys))

        subjects = subjects.values.sort_by { |s| s[:aa] }
        completion = determine_level_completion(session, subjects)

        subjects = subjects.select { |s| s[:ssi][0, 1] == 'a' }

        [ completion, subjects ]
      end

      def apprentice_html

        completion, subjects = apprentice()

        #max_level = subjects.collect { |s| s[:l] }.max
        max_level = completion[:max_level]
        levels = subjects.partition { |s| s[:l] == max_level }

        Html.generate {
          head do
            meta charset: 'UTF-8'
            title "WK Apprentice - #{Time.now.strftime('%F %A %R')}"
            link href: FONT_HREF, rel: 'stylesheet'
            style do
              File.read(File.join(File.dirname(__FILE__), 'reset.css')) +
              File.read(File.join(File.dirname(__FILE__), 'common.css')) +
              File.read(File.join(File.dirname(__FILE__), 'apprentice.css'))
            end
          end
          body do
            levels.each do |ss|
              current_level = ss.first[:l] == max_level
              div k: [ 'level', current_level ? 'current' : 'old' ] do
                ss.each do |s|
                  div k: [ 'subject', s[:o], s[:ssi] ], 'data-subject-id': s[:sid].to_s do
                    div k: 'text' do
                      subject_to_anchor(s)
                    end
                    div k: 'level' do
                      s[:l]
                    end
                    #div k: 'last' do
                    #  s[:last] ? '*' : ''
                    #end
                    div k: 'ssi' do
                      '|' * s[:ssi][1..-1].to_i
                    end
                    div k: 'next' do
                      #Time.now.day == s[:aa].day ? s[:aa].strftime('%H') : ''
                      n = Time.now
                      if n.day == s[:aa].day
                        s[:aa].strftime('%H')
                      elsif s[:aa] < (n + 24 * 3600)
                        s[:aa].strftime('%a')[0, 2].downcase +
                        s[:aa].strftime('%H')
                      else
                        ''
                      end
                    end
                  end
                end
                div k: 'count' do
                  div k: 'k' do
                    "k#{ss.select { |s| s[:o] == 'k' }.size}"
                  end
                  div k: 'r' do
                    "r#{ss.select { |s| s[:o] == 'r' }.size}"
                  end
                  div k: 'total' do
                    ss.size
                  end
                  div k: 'over' do
                    current_level ?
                      completion[:min_time].strftime('%F %A %R') :
                      ''
                  end
                end
              end
            end
            levels.each do |ss|
              ss.each do |s|
                div k: [ 'subject-detail', s[:o], 'hidden' ], 'data-subject-id': s[:sid] do
                  table do
                    tr do
                      td k: 'text', rowspan: '2' do
                        subject_to_anchor(s)
                      end
                      td k: 'readings', colspan: 2 do
                        rs = s[:rs] || []
                        rs << '&nbsp;' while rs.size < 4
                        rs.each { |r| div k: 'reading' do; r; end }
                      end
                      td k: 'meanings',  colspan: 2 do
                        s[:ms].join(', ')
                      end
                    end
                    tr k: 'data' do
                      td k: 'level' do; s[:l]; end
                      td k: 'ssi' do; s[:ssi]; end
                      td k: 'pc' do; "#{s[:pc]}%"; end
                      td k: 'next' do; s[:aa].strftime('%a %d %R'); end
                    end
                  end
                end
              end
            end
            script do
              File.read(File.join(File.dirname(__FILE__), 'h-1.2.0.min.js'))
            end
            script do
              File.read(File.join(File.dirname(__FILE__), 'apprentice.js'))
            end
          end
        }.to_s
      end

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

        subject_ids = subject_ids.to_a
        #subject_ids = subject_ids.to_a[0, 1000]

        subjects = {}
          #
        merge!(subjects, session.subjects(subject_ids))
        merge!(subjects, session.assignments(subject_ids))
        merge!(subjects, session.rstatistics(subject_ids))

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
              s[:sid], s[:l], s[:o], s[:t],
              (s[:rs] || []).join(', '), s[:ms].join(', '))
          end
        end
        puts
      end

      def upcoming_html(*types)

        types = %w[ r k t ] if types.empty?
        types = types.collect(&:to_s)

        count = 0
        u = upcoming

        max_level = u.collect(&:last).flatten(1).collect { |s| s[:l] }.max

        Html.generate {
          head do
            meta charset: 'UTF-8'
            title "WK Upcoming - #{u.first[0].strftime('%F %A %R')}"
            link href: FONT_HREF, rel: 'stylesheet'
            style do
              File.read(File.join(File.dirname(__FILE__), 'reset.css')) +
              File.read(File.join(File.dirname(__FILE__), 'common.css')) +
              File.read(File.join(File.dirname(__FILE__), 'upcoming.css'))
            end
          end
          body do
            table class: 'upcoming' do
              u.each do |time, subjects|
                tr class: 'time' do
                  td colspan: 3
                  td class: 'time', colspan: 4 do time.strftime('%F %A %R') end
                  td class: 'count', colspan: 1 do
                    span class: 'size' do subjects.size end
                    span class: 'count' do count += subjects.size end
                  end
                end
                subjects.each do |s|
                  tr class: [ s[:o], "l#{s[:l]}", s[:ssi] ] do
                    cur = s[:l] == max_level ? 'current' : nil
                    td class: 'id' do s[:sid] end
                    td class: 'type' do s[:o] end
                    td class: [ 'level', cur ].compact do s[:l] end
                    td class: 'text' do; subject_to_anchor(s); end
                    td class: 'srs' do s[:ssi] end
                    td class: 'pc' do "#{s[:pc]}%" end
                    td class: 'readings' do (s[:rs] || []).join(', ') end
                    td class: 'meanings' do s[:ms].join(', ') end
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

      protected

      H1, H4, H8, H24, H48 = [ 1, 4, 8, 24, 48 ].collect { |i| i * 3600 }

      TIMES = [
        H4 + H8 + H24 + H48 - H1,
        H8 + H24 + H48,
        H24 + H48,
        H48,
        0 ]

      def determine_guru_time(subject)

        return Time.now if subject[:ss] > 4

        subject[:aa] + TIMES[subject[:ss]]
      end

      def determine_level_completion(session, subjects)

        ml = subjects.collect { |s| s[:l] }.max
        subjects = subjects.select { |s| s[:l] == ml }

        lkrs = session.level_krs(ml)
        ninety = (lkrs.select { |s| s[:o] == 'k' }.size * 0.9).ceil

        rs, ks = subjects.partition { |s| s[:o] == 'r' }

        last_subject =
          if ks.size >= ninety
            levels = ks
              .inject({}) { |h, s| (h[s[:ss]] ||= []) << s; h }
            levels = (1..5).to_a
              .reverse
              .collect { |ss| (levels[ss] || []).sort_by { |s| s[:aa] } }
            ks = levels
              .reduce { |a, l| a.concat(l) }
            ks[0, ninety].last
          else
            lowest = rs
              .collect { |s| s[:ss] }.min
            rs
              .select { |s| s[:ss] == lowest }
              .sort_by { |s| s[:aa] }
              .last
          end

        last_subject[:last] = true

        mt = determine_guru_time(last_subject)
        mt += TIMES[0] - H1 if last_subject[:o] == 'r'

        { max_level: ml, min_time: mt }
      end

      def merge!(subjects, elts)

        elts = elts['data'] if elts['data'].is_a?(Array)

        o =
          case obj = elts.first['object']
          when 'kanji', 'radical', 'vocabulary' then 'subject'
          else obj
          end

        m = "#{o}_to_h"

        elts.each { |e|
          h = send(m, e)
          s = (subjects[h[:sid]] ||= {})
          s.merge!(h) }

        subjects
      end

      def assignment_to_h(a)

        d = a['data']

        sid = d['subject_id']
        ss = d['srs_stage']
        ssn = d['srs_stage_name']

        ssi = ssn[0, 1] + ss.to_s
        ssi = ssi.downcase if ssn.match(/^A/)

        aa = Time.parse(d['available_at']).localtime

        { sid: sid, ss: ss, ssn: ssn, ssi: ssi, aa: aa }
      end

      def subject_to_h(s)

        d = s['data']

        t =
          d['characters']
        ti =
          t ||
          d['character_images']
            .find { |ci| ci['metadata']['dimensions'] == '32x32' }
            .fetch('url')
        o =
          s['object'][0, 1]

        rs = d['readings']
        if rs
          rs.each do |r|
            r['reading'] = "(#{r['reading']})" unless r['accepted_answer']
          end
          prs, nprs = rs.partition { |r| r['primary'] }
          rs = (prs + nprs).collect { |r| r['reading'] }
        end

        { sid: s['id'],
          l: d['level'],
          #cl: d['level'] == current_level,
          o: o,
          t: t,
          ti: ti,
          rs: rs,
          ms: d['meanings'].map { |m| m['meaning'] },
          pos: d['part_of_speech'] }
      end

      def review_statistic_to_h(s)

        d = s['data']

        { sid: d['subject_id'],
          mc: d['meaning_correct'], mi: d['meaning_incorrect'],
          mms: d['meaning_max_streak'], mcs: d['meaning_current_streak'],
          rc: d['reading_correct'], ri: d['reading_incorrect'],
          rms: d['reading_max_streak'], rcs: d['reading_current_streak'],
          pc: d['percentage_correct'] }
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
        #def method_missing(m, *args, &block)
        #  @children << Html.new(m, args, &block)
        #end
        %w[
          html
            head meta style title link script
            body div span table tr th td a img
        ].each do |tag|
          define_method(tag) do |*args, &block|
            @children << Html.new(tag, args, &block)
          end
        end
        def to_s
          atts = @attributes
            .map { |k, v|
              k = 'class' if k == :k
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

      # Re-opening to add a special method sitting on a fence...
      #
      class Html

        def subject_to_anchor(s)

          if s[:o] == 'k'
            a href: "#{WWW_URI}kanji/#{s[:t]}", target: '_blank' do
              s[:t]
            end
          elsif s[:o] == 'r' && s[:t] == nil
            a href: "#{WWW_URI}radicals/#{s[:ms][0]}", target: '_blank' do
              img src: s[:ti]
            end
          elsif s[:o] == 'r'
            a href: "#{WWW_URI}radicals/#{s[:ms][0]}", target: '_blank' do
              s[:t]
            end
          else
            a href: "#{WWW_URI}vocabulary/#{s[:t]}", target: '_blank' do
              s[:t]
            end
          end
        end
      end
    end
  end
end

