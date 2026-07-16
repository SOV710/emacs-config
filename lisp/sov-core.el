;;; sov-core.el --- Core Emacs behavior -*- lexical-binding: t; -*-

;; startup and performance
(setq gc-cons-threshold (* 64 1024 1024) ; 设置触发垃圾回收前允许分配的字节数
      gc-cons-percentage 0.2 ; 设置相对堆大小增长多少后允许垃圾回收
      read-process-output-max (* 1024 1024) ; 限制 Emacs 单次从子进程读取的最大字节数, 提高后可减少大消息分片, 但会增大瞬时分配
      process-adaptive-read-buffering nil ; 关闭后, Emacs 通常会更及时地处理已经到达的进程输出
      inhibit-startup-screen t ; 跳过 Emacs 启动画面, 直接显示初始 buffer
      initial-scratch-message nil ; 关闭 *scratch* buffer 初始文本
      )

;; customize
(setq custom-file (locate-user-emacs-file "custom.el")) ; 默认情况下, Customize 可能把内容直接写进你的 init.el, 要隔离这种自动生成的代码
(load custom-file 'noerror)


;; file, persistence and history
(setq recentf-max-saved-items 200 ; 限制 recentf 持久化的最近文件数量
      history-length 1000 ; 设置多数 minibuffer 历史列表保留的最大长度
      history-delete-duplicates t ; 新增历史项时删除旧的重复项
      auto-revert-verbose nil ; 关闭 auto-revert-mode 的重载提示消息
      delete-by-moving-to-trash t ; 让删除文件命令优先移入系统回收站
      )

(recentf-mode 1) ; 记录最近访问的文件, 并提供持久化列表
(savehist-mode 1) ; 跨会话保存 minibuffer 历史及额外指定的变量
(save-place-mode 1) ; 近似 ShaDa 恢复 cursor position
(global-auto-revert-mode 1) ; 当文件在编辑器外部被修改时, 自动重新读取磁盘上的最新内容, 无需手动确认


;; display and interface
(setq-default display-line-numbers-type 'relative ; 相对行号
              cursor-type 'bar ; 光标形状
              ring-bell-function #'ignore ; 禁用响铃铃声
              )

(menu-bar-mode -1) ; 隐藏 GUI 顶层第一行菜单栏
(tool-bar-mode -1) ; 隐藏 GUI 顶层第二行工具栏
(scroll-bar-mode -1) ; 隐藏左侧图形滚动条
(global-display-line-numbers-mode t) ; 全局开启列号
(global-hl-line-mode 1) ; 全局高亮当前视觉行
(column-number-mode 1) ; mode-line 不显示列号
(show-paren-mode 1) ; 开启括号匹配高亮
(blink-cursor-mode -1) ; 全局禁用光标闪烁

;; soft wraping
(require 'kinsoku)
(setq-default truncate-lines nil ; 软换行, 拒绝强行截断
              word-wrap t ; 软换行在单词边界断开, 而不是窗口边缘
              word-wrap-by-category t ; 改善 CJK 单词软换行体验
              )

(require 'visual-wrap)
(setq visual-wrap-extra-indent 0) ; 原行换行不额外缩进字符
(global-visual-line-mode 1) ; 全局开启视觉行, 不使用逻辑行
(global-visual-wrap-prefix-mode 1) ; 让软换行后的续行继承原逻辑行的缩进


;; editing indentation and whitespace
(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 100)

(setq sentence-end-double-space nil ; 不要求标点后两个空格
      tab-always-indent 'complete ; tab 先尝试补全再尝试缩进
      kill-ring-max 1000 ; 剪贴板大小
      require-final-newline t ; 保存文件时自动补末尾换行
      )

(electric-pair-mode 1) ; autopair
(electric-indent-mode 1) ; autoindent


;; search, replace and navigation
(setq-default case-fold-search t
              ); 搜索和匹配默认忽略大小写

(setq scroll-margin 5 ; 在 cursor 上下保留 10 行
      scroll-conservatively 101 ; cursor 越过边界后不自动重新居中
      recenter-positions '(middle top bottom) ; recenter-top-bottom 循环顺序
      )

(repeat-mode 1) ; 让支持 repeat-map 的命令可用短键连续重复


;; completion and minibuffer

(setq completion-styles '(basic substring partial-completion) ; 搜索匹配算法顺序
      completion-category-defaults nil ; 所有类别直接采用你的 completion-styles
      completion-cycle-threshold 3 ; 候选不超过 3 个时循环
      completion-ignore-case t ; completion 忽略大小写
      read-buffer-completion-ignore-case t ; 读取 buffer 名忽略大小写
      read-file-name-completion-ignore-case t ; 文件名补全忽略大小写
      minibuffer-prompt-properties '(read-only t cursor-intangible t face minibuffer-prompt) ; minibuffer 属性
      )


;; windows, frames and buffers
(require 'uniquify)
(setq window-combination-resize t ; 调整一个窗口大小时把同组合中的其他窗口作为整体重新分配
      frame-resize-pixelwise t ; 像素级缩放 frame
      use-dialog-box nil ; 绝不使用图形对话框
      use-file-dialog nil ; 禁止使用系统文件选择对话框
      use-short-answers t ; 让 yes-or-no 问题接受 y/n 简短回答
      uniquify-buffer-name-style 'forward ; 打开同名文件时, Emacs 在前面加路径区分它们
      )


;; undo backup and auto save
(make-directory (locate-user-emacs-file "backups/") t)
(make-directory (locate-user-emacs-file "auto-save/") t)

(setq make-backup-files t ; Emacs 保存文件创建备份文件, 即 *~ 文件
      backup-directory-alist `(("." . ,(locate-user-emacs-file "backups/"))) ; 将 Emacs 备份文件统一放在用户管理系统的 backups/ 下
      backup-by-copying t ; 用复制而非重命名原文件的方式制作备份
      version-control t ; 每次生成带编号的备份, 可以保留历史版本
      kept-new-versions 6 ; 保留 6 个较新版本
      kept-old-versions 2 ; 保留 2 个较旧版本
      delete-old-versions t ; 超过保留数量时自动删除旧编号备份
      auto-save-default t ; 普通文件启用自动保存
      auto-save-file-name-transforms `((".*" ,(locate-user-emacs-file "auto-save/") t))
      )



(setq use-short-answers t
      confirm-kill-emacs #'yes-or-no-p
      sentence-end-double-space nil)



(delete-selection-mode 1)


(provide 'sov-core)
