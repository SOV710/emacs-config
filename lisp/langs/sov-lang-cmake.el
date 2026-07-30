;;; sov-lang-cmake.el --- CMake Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'cmake
 '((:language cmake
    :url "https://github.com/uyha/tree-sitter-cmake"
    :fallback cmake-mode
    :ts-mode cmake-ts-mode
    :patterns ("CMakeLists\\.txt\\'" "\\.cmake\\'"))))

(provide 'sov-lang-cmake)
;;; sov-lang-cmake.el ends here
