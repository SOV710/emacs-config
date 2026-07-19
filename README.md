<div align="center">

  <img src="https://preview.github.sov710.org/emacs-config/emacs-logo.svg" width="200" height="200">

  # SOV710's Emacs Configuration

  [![Stand With Palestine](https://img.shields.io/badge/Stand_With-Palestine-007A3D?style=flat-square&labelColor=000000)](https://www.un.org/unispal/)
  [![License](https://img.shields.io/github/license/SOV710/emacs-config?style=flat-square&labelColor=1a1b26&color=bb9af7)](LICENSE)
  [![Last Commit](https://img.shields.io/github/last-commit/SOV710/emacs-config?style=flat-square&labelColor=1a1b26&color=7aa2f7)](https://github.com/SOV710/emacs-config/commits/main)
  [![Stars](https://img.shields.io/github/stars/SOV710/emacs-config?style=flat-square&labelColor=1a1b26&color=7aa2f7&logo=github&logoColor=white)](https://github.com/SOV710/emacs-config/stargazers)
  [![Neovim]( https://img.shields.io/badge/Emacs-30.1%2B-7F5AB6?style=flat-square&labelColor=1a1b26&logo=gnuemacs&logoColor=white)](https://www.gnu.org/savannah-checkouts/gnu/emacs/emacs.html)

</div>


## Dependencies

- [`fd`](https://github.com/sharkdp/fd)
- [`ripgrep`](https://github.com/BurntSushi/ripgrep)
- [Node.js](https://nodejs.org/)

`math-preview` uses a Node.js companion program.  After the first Emacs start,
Elpaca downloads the package source to `elpaca/sources/math-preview/`.  Install
the companion's production dependencies from that directory with **one** of
the following package managers:

### npm

```sh
cd elpaca/sources/math-preview
npm install --omit=dev
```

### Yarn

```sh
cd elpaca/sources/math-preview
yarn install --production
```

### pnpm

```sh
cd elpaca/sources/math-preview
pnpm install --prod
```

### Bun

```sh
cd elpaca/sources/math-preview
bun install --production
```

These package managers are alternatives; only Node.js is required at runtime.
After installing the dependencies, `math-preview` can start its companion
process automatically when a Markdown buffer is opened.


## Plugins

This table lists each external package bootstrapped or installed by this
configuration.  All entries use Elpaca, except Elpaca itself, which is
bootstrapped by `init.el`.  Components configured with `:ensure nil`, such as
`which-key`, `project`, `dired`, and `org`, are not external packages and are
therefore omitted.

| Package | Area | Used for |
| --- | --- | --- |
| `elpaca` | Package management | Bootstrap, build, and install packages from source repositories. |
| `elpaca-use-package` | Package management | Route `use-package :ensure` recipes through Elpaca. |
| `evil` | Modal editing | Provide Vim-style states, motions, operators, and keymaps. |
| `evil-collection` | Modal editing | Add consistent Evil bindings to Emacs and third-party package modes. |
| `evil-surround` | Modal editing | Add, delete, and replace surrounding delimiters. |
| `flash` | Navigation | Jump quickly to visible targets across windows. |
| `rainbow-delimiters` | Editing | Color nested delimiters in Lisp-family buffers. |
| `vundo` | Editing | Browse and restore states through a visual undo tree. |
| `orderless` | Completion | Match completion candidates by unordered space-separated components. |
| `vertico` | Completion | Display completion candidates in a compact vertical minibuffer UI. |
| `marginalia` | Completion | Annotate completion candidates with contextual metadata. |
| `consult` | Completion and search | Provide enhanced buffer switching, navigation, file finding, and search commands. |
| `embark` | Actions | Offer context-sensitive actions for the target at point or selected candidate. |
| `embark-consult` | Completion integration | Preserve Consult previews in Embark collect and export buffers. |
| `dirvish` | File manager | Extend Dired with a modern file manager and side panel. |
| `projectile` | Projects | Track projects and provide the Dashboard project backend. |
| `dashboard` | Startup | Display recent files, bookmarks, and projects at startup. |
| `page-break-lines` | Dashboard | Render Dashboard page breaks as clean horizontal rules. |
| `all-the-icons` | Dashboard | Supply Dashboard's compatibility icon dependency. |
| `tokyo-night` | Theme | Provide the active Tokyo Night color theme. |
| `nerd-icons` | Icons | Render icons in the mode line, Dashboard, and Dirvish. |
| `diff-hl` | Version control | Show changed hunks and provide change counts for the custom mode line. |
| `indent-bars` | Display | Draw indentation guides in programming buffers. |
| `colorful-mode` | Display | Preview color literals in supported markup and programming buffers. |
| `pulsar` | Navigation feedback | Pulse destinations after jumps and searches. |
| `valign` | Tables | Align Org and Markdown tables by rendered pixel width. |
| `markdown-mode` | Markdown | Edit and fontify conventional Markdown files. |
| `markdown-ts-mode` | Markdown | Provide a Tree-sitter-based Markdown mode where Emacs does not bundle one. |
| `markdown-table-wrap` | Markdown tables | Wrap and unwrap wide Markdown pipe tables. |
| `math-preview` | Mathematics | Render LaTeX math as in-buffer MathJax SVG previews. |


## Keybindings

The following tables list every keybinding explicitly declared by this
configuration.  They do not repeat the defaults supplied unchanged by Emacs,
Evil, Evil Collection, or individual packages.

| Notation | Value |
| --- | --- |
| `<leader>` | `SPC` in Normal, Visual, and Motion states |
| `<localleader>` | `,` in Normal, Visual, and Motion states |

### Global

| Key | State / context | Command | Purpose |
| --- | --- | --- | --- |
| `C-u` | Normal | `evil-scroll-up` | Scroll up using Vim-style behavior. |
| `<leader>wh` | Normal, Visual, Motion | `split-window-below` | Split the current window below. |
| `<leader>wv` | Normal, Visual, Motion | `split-window-right` | Split the current window to the right. |
| `<leader>wd` | Normal, Visual, Motion | `delete-window` | Delete the current window. |
| `C-h` | Normal, Visual, Motion | `windmove-left` | Focus the window to the left. |
| `C-j` | Normal, Visual, Motion | `windmove-down` | Focus the window below. |
| `C-k` | Normal, Visual, Motion | `windmove-up` | Focus the window above. |
| `C-l` | Normal, Visual, Motion | `windmove-right` | Focus the window to the right. |
| `C-S-h` | Normal, Visual, Motion | `shrink-window-horizontally` | Make the current window narrower. |
| `C-S-l` | Normal, Visual, Motion | `enlarge-window-horizontally` | Make the current window wider. |
| `C-S-k` | Normal, Visual, Motion | `enlarge-window` | Make the current window taller. |
| `C-S-j` | Normal, Visual, Motion | `shrink-window` | Make the current window shorter. |
| `<leader>qq` | Normal, Visual, Motion | `save-buffers-kill-emacs` | Save modified buffers as needed, close Emacs, and request final confirmation. |
| `m` | Normal | `bookmark-set` | Set a bookmark. |
| `C-'` | Normal | `bookmark-jump` | Jump to a bookmark. |
| `'` | Normal | `list-bookmarks` | List bookmarks. |
| `C-a` | Normal | `sov-evil-select-whole-buffer` | Select the entire accessible buffer in Visual Line state. |
| `C-S-v` | Global Emacs map | `yank` | Paste from the kill ring. |

### Completion, Search, and Actions

| Key | State / context | Command | Purpose |
| --- | --- | --- | --- |
| `C-j` | Vertico minibuffer | `vertico-next` | Select the next completion candidate. |
| `C-k` | Vertico minibuffer | `vertico-previous` | Select the previous completion candidate. |
| `<leader>sb` | Normal, Visual, Motion | `consult-project-buffer` | Switch to a project buffer. |
| `<leader>sf` | Normal, Visual, Motion | `project-find-file` | Find a file in the current project. |
| `<leader>sd` | Normal, Visual, Motion | `consult-fd` | Find files with `fd`, including VCS-ignored files. |
| `<leader>sg` | Normal, Visual, Motion | `consult-ripgrep` | Search project contents with ripgrep. |
| `M-p` | Global Emacs map | `consult-yank-pop` | Browse and insert from the kill ring. |
| `C-.` | Global Emacs map | `embark-act` | Select an action for the target at point or current candidate. |
| `C-;` | Global Emacs map | `embark-dwim` | Run Embark's context-sensitive default action. |
| `C-h B` | Global Emacs map | `embark-bindings` | Show bindings available for the target at point. |

### Vundo

| Key | State / context | Command | Purpose |
| --- | --- | --- | --- |
| `<leader>us` | Normal, Visual, Motion | `vundo` | Open the undo tree. |
| `h` | Normal in `vundo-mode` | `vundo-backward` | Move backward in the undo tree. |
| `l` | Normal in `vundo-mode` | `vundo-forward` | Move forward in the undo tree. |
| `j` | Normal in `vundo-mode` | `vundo-next` | Move to the next branch. |
| `k` | Normal in `vundo-mode` | `vundo-previous` | Move to the previous branch. |
| `G` | Normal in `vundo-mode` | `vundo-goto-last-saved` | Move to the last saved state. |
| `n` | Normal in `vundo-mode` | `vundo-goto-next-saved` | Move to the next saved state. |
| `r` | Normal in `vundo-mode` | `vundo-stem-root` | Move to the root of the current undo stem. |

### Evil Surround and Flash

| Key | State / context | Command | Purpose |
| --- | --- | --- | --- |
| `gaa{motion}` | Normal | `evil-surround-edit` | Add a surrounding pair around the following motion or text object. |
| `gaA{motion}` | Normal | `evil-Surround-edit` | Add a surrounding pair with surrounding newlines. |
| `gad` | Normal | `evil-surround-delete` | Delete a surrounding pair. |
| `gar` | Normal | `evil-surround-change` | Replace a surrounding pair. |
| `gaa` | Visual | `evil-surround-region` | Add a surrounding pair around the selected region. |
| `gaA` | Visual | `evil-Surround-region` | Add a surrounding pair with surrounding newlines around the selected region. |
| `s` | Normal, Visual, Motion, Operator-pending | `flash-evil-jump` | Jump to a visible target; in Operator-pending state, use it as the operator target. |

### Dirvish

| Key | State / context | Command | Purpose |
| --- | --- | --- | --- |
| `<leader>o` | Normal, Visual, Motion | `dirvish-dwim` | Open Dirvish for the current location. |
| `<leader>e` | Normal, Visual, Motion | `sov-dirvish-side-toggle` | Open or close Dirvish Side. |
| `a` | Normal in any `dirvish-mode` buffer | `sov-dirvish-create-entry` | Create an empty file, or a directory when the name ends in `/`. |
| `h` | Normal in `dirvish-mode` | `dired-up-directory` | Visit the parent directory. |
| `l` | Normal in `dirvish-mode` | `sov-dirvish-side-toggle-or-open` | Toggle a directory subtree in Dirvish Side, or visit the entry. |
| `RET` | Normal in `dirvish-mode` | `sov-dirvish-side-toggle-or-open` | Toggle a directory subtree in Dirvish Side, or visit the entry. |
| `SPC e` | Normal in `dirvish-mode` | `sov-dirvish-side-toggle` | Open or close Dirvish Side. |

### Markdown and Math Preview

These bindings apply to both `markdown-mode` and `markdown-ts-mode`.

| Key | State | Command | Purpose |
| --- | --- | --- | --- |
| `<leader>ma` | Normal, Visual | `math-preview-all` | Render every math expression in the buffer. |
| `<leader>mr` | Normal | `math-preview-at-point` | Render the math expression at point. |
| `<leader>mr` | Visual | `math-preview-region` | Render math expressions in the selected region. |
| `<leader>mc` | Normal, Visual | `math-preview-clear-all` | Clear all math previews in the buffer. |
| `<leader>md` | Normal | `math-preview-clear-at-point` | Clear the math preview at point. |
| `<leader>md` | Visual | `math-preview-clear-region` | Clear math previews in the selected region. |
| `<localleader>tw` | Normal | `sov-markdown-table-wrap-at-point` | Wrap the pipe table at point to the current window width. |
| `<localleader>tu` | Normal | `sov-markdown-table-unwrap-at-point` | Unwrap the marked pipe table at point. |
| `<localleader>tU` | Normal | `sov-markdown-table-unwrap-buffer` | Unwrap every marked pipe table in the buffer. |

### Command Remaps

These are global command remaps rather than direct key sequences: any binding
that invokes the command in the first column uses the replacement instead.

| Original command | Replacement | Purpose |
| --- | --- | --- |
| `switch-to-buffer` | `consult-buffer` | Use Consult when switching buffers. |
| `project-switch-to-buffer` | `consult-project-buffer` | Use Consult when switching project buffers. |
| `goto-line` | `consult-goto-line` | Use Consult for line navigation. |
| `imenu` | `consult-imenu` | Use Consult for index navigation. |
