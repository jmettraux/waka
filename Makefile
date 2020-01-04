
## specific to project ##
RUBY=ruby

summary:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('./.wanikani_api_token').summary"
s: summary

subjects:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('.').subjects(6184, 5970, 306, 8792)"
ss: subjects

assignments:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('.').assignments(6184, 5970)"
as: assignments

reviews:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('.').reviews(6184, 5970)"
rs: reviews

rstatistics:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('.').rstatistics(6184, 5970)"
rss: rstatistics

lprogressions:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('.').lprogressions"
lps: lprogressions

apprentice:
	$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.apprentice"
ace: apprentice

upcoming:
	#$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_text(:r, :k)"
	#$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_html"
	$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_html" > out.html
u: upcoming

.PHONY: \
  summary subjects assignments reviews rstatistics lprogressions \
  upcoming

