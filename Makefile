
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
      -e "pp Waka::Session.new('.').subjects(6184, 5970)"
ss: subjects

assignments:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('.').assignments(6184, 5970)"
as: assignments

upcoming:
	#$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_text(:r, :k)"
	#$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_html"
	$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_html" > out.html
u: upcoming

.PHONY: summary subjects assignments upcoming

