# The terminal recording in the README: a var change rolled out to the db
# group, a hand edit on the server, and drift catching it. Recorded against
# the push lab with `rake docs:recording`; the output is real.

Output "/out/demo.gif"

Set Shell "bash"
# The widest line is 115 characters (a diff line in the apply output) and
# the apply screen is 29 lines: this holds about 120 columns and 32 lines.
# Not much wider than that, so the text stays readable when the docs and
# the README scale the recording down to their column width.
Set FontSize 17
Set LetterSpacing 0
Set Width 1260
Set Height 760
Set Padding 14
Set TypingSpeed 40ms
Set Theme "Builtin Dark"

Hide
Type "cd /tmp/fleet && export PS1='$ ' && clear"
Enter
Show

Type "grep backup_hour hosts.rb"
Sleep 300ms
Enter
Sleep 1.5s

Type "sadame plan site.rb -g db"
Sleep 300ms
Enter
Sleep 4s

Type "clear"
Enter
Type "sadame apply site.rb -g db"
Sleep 300ms
Enter
Sleep 4s

Type "clear"
Enter
Type `ssh -p 2222 deploy@db1.example.com "sudo sed -i 's/^0 4/0 5/' /etc/cron.d/demo-db-backup"`
Sleep 300ms
Enter
Sleep 2s

Type "sadame drift site.rb -g db; echo exit status $?"
Sleep 300ms
Enter
Sleep 5s
