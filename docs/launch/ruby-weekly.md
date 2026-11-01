# Ruby Weekly submission

**Title:** Sadame: configuration management in plain Ruby, in one binary

**Link:** https://github.com/enderkus/sadame

**Blurb (about 50 words):**

Sadame describes Linux machines in Ruby recipes, shows every change as a
diff with `plan`, applies it, and checks for drift from CI. It is a single
static mruby binary that copies itself to servers over SSH, so they need no
Ruby. 0.1.0 has six resource types and a Ruby inventory.
