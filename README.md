# File::Copy::Recursive round 2


I have gotten much love from this module but it has suffered from neglect. Partly because I am busy and partly that the code is crusty (it was done back when package globals were all the rage–those of you with CGI tatoos know what I am talking about ;)).

So I am finally making a plan to give this the attentiuon it deserves.

## Goals

1. Fix the [RTs](https://rt.cpan.org/Dist/Display.html?Queue=File-Copy-Recursive) (pull requests welcome!)
2. Modernize the code and interface
3. Do not break existing consumers of the legacy interface

I will create issues/branches for items 2 and 3 as they progress if you'd like to help.