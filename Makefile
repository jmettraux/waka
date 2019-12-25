
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

upcoming:
	$(RUBY) -Ilib -r pp -r waka -e "pp Waka::Reports.upcoming_text(:r, :k)"
u: upcoming

.PHONY: summary

