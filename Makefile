# REGRESSION TESTS
#
# Run with the command
#
#   make
#
# Each test is a shell script with a name ending in .sh in the tests
# directory. It must exit with status code 0 (test succeeded), 2 (test
# not applicable) or any other code (test failed). Any output is
# captured in a log file.

TESTS := $(sort $(wildcard tests/*.sh))
RESULTS := $(TESTS:.sh=.result)

ECHO=/bin/echo

# Terminal escape codes for red, green and blue
CLR_EOL := $(shell tput el)
FAIL := $(shell tput setaf 1)FAIL$(shell tput op)
OK := $(shell tput setaf 2)OK$(shell tput op)
NA := $(shell tput setaf 4)N/A$(shell tput op)

%: %.sh markdown.awk
	@$(SHELL) $< >$*.log 2>&1; \
	 case $$? in \
	 0) $(ECHO) -n "$< $(OK)$(CLR_EOL)"; $(ECHO) OK >$*.result;; \
	 2) $(ECHO) -n "$< $(NA)$(CLR_EOL)"; $(ECHO) N/A >$*.result;; \
	 *) $(ECHO) "$< $(FAIL)$(CLR_EOL)"; $(ECHO) FAIL >$*.result;; \
	 esac

check: $(TESTS:.sh=)
	@$(ECHO) "====================$(CLR_EOL)"
	@$(ECHO) "$(OK)  " `grep OK $(RESULTS) | wc -l`
	@$(ECHO) "$(FAIL)" `grep FAIL $(RESULTS) | wc -l`
	@$(ECHO) "$(NA) " `grep N/A $(RESULTS) | wc -l`
	@test `grep FAIL $(RESULTS) | wc -l` -eq 0
