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
