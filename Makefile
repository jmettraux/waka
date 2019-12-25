
## specific to project ##
RUBY=ruby

summary:
	$(RUBY) \
      -Ilib -r pp -r waka \
      -e "pp Waka::Session.new('./.wanikani_api_token').summary"
s: summary

.PHONY: summary

