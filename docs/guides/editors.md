# Editor support

`sadame lsp` is a language server: an editor starts it and, while you
write a recipe, shows what `sadame validate` would find, completes
resources, options and facts, and describes them when you point at them.
It is in the same binary as the rest of sadame; nothing else to install.

!!! note "New in 0.5.0"

## What it does

| In the editor | From |
|---|---|
| Errors under the line they are on: misspelled options, unknown resources, Ruby errors, notifications to resources that are not declared, template errors (shown on the template) | the recipe evaluated for every host in the nearest `hosts.rb`, with its vars, as [validate](../reference/cli.md#validate) does, on every change |
| Completion of resources and recipe helpers at the start of a line, of a resource's options inside its arguments, of `state:` values, and of fact names after `facts[:` | the resource pages of these docs |
| Hover text for resources, options, facts and helpers | the same pages |
| The recipe's resources in the outline or symbol list | the recipe's lines |

A file that a recipe includes, such as `roles/web.rb`, is checked through
that recipe and only for the hosts that include it, so a role for web
servers is not checked with a database server's vars.

## Setting it up

The server runs as `sadame lsp`, on recipe files (`.rb`) in a directory
that has, or has above it, a `recipe.rb`, `site.rb`, `vars.rb` or
`hosts.rb`. It can run next to a Ruby language server such as Ruby LSP or
Solargraph: those know Ruby, sadame knows recipes.

### Neovim 0.11 and later

```lua
vim.lsp.config("sadame", {
  cmd = { "sadame", "lsp" },
  filetypes = { "ruby" },
  root_markers = { "hosts.rb", "vars.rb", "recipe.rb", "site.rb" },
})
vim.lsp.enable("sadame")
```

### Neovim 0.10

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(args)
    local root = vim.fs.root(args.buf, { "hosts.rb", "vars.rb", "recipe.rb", "site.rb" })
    if root then
      vim.lsp.start({ name = "sadame", cmd = { "sadame", "lsp" }, root_dir = root })
    end
  end,
})
```

### Helix

In `languages.toml`, add the server and list it for Ruby, next to the
servers you already use:

```toml
[language-server.sadame]
command = "sadame"
args = ["lsp"]

[[language]]
name = "ruby"
language-servers = ["sadame", "ruby-lsp"]
```

### Emacs

With Eglot, which runs one server per buffer, sadame replaces the Ruby
server in recipe buffers:

```elisp
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '((ruby-mode ruby-ts-mode) "sadame" "lsp")))
```

### VS Code

VS Code starts language servers through extensions, and sadame has none
yet. An extension that runs a configurable language server command can
start `sadame lsp`.

## Options

The client can pass `initializationOptions` when it starts the server:

| Option | Default | Meaning |
|---|---|---|
| `platform` | `"debian"` | The system recipes are checked as, as `validate --platform`: `debian`, `ubuntu`, `rocky`, `alpine` or `arch`. |

In Neovim: `init_options = { platform = "rocky" }` in the configuration
above.

## Good to know

- **The recipe runs while you type.** Like `validate`, the server evaluates
  the recipe on every change, against a stand-in machine that runs no
  commands. Ruby code at the top of a recipe runs too, which is one more
  reason to keep side effects in resources.
- **`hosts.rb` is read once**, when the server first needs it, and again
  when you save it, `vars.rb` or a template. A dynamic inventory runs its
  command then.
- **What depends on the machine is not checked.** A package name that does
  not exist, a service that is not installed: `plan` finds those.

## Common mistakes

- **No project around the file.** A Ruby file without a `recipe.rb`,
  `site.rb`, `vars.rb` or `hosts.rb` in its directory or above gets no
  errors, so that other Ruby code in the editor is left alone.
- **An old sadame on the `PATH`.** The editor starts whichever `sadame` it
  finds first; `sadame --version` should say 0.5.0 or later.
- **Expecting errors only after saving.** They follow every change; an
  error while a line is half written is normal and goes away with it.

## See also

- [Command line](../reference/cli.md#validate) for `validate`, which the
  editor's checks follow.
- [Recipe basics](../recipes/basics.md), [Facts](../recipes/facts.md) and
  the resource pages, which the completions and hover text come from.
