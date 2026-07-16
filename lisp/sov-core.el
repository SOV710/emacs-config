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
              )

(menu-bar-mode -1) ; 隐藏 GUI 顶层第一行菜单栏
(tool-bar-mode -1) ; 隐藏 GUI 顶层第二行工具栏
(scroll-bar-mode -1) ; 隐藏左侧图形滚动条
(global-display-line-numbers-mode t) ; 全局开启列号
(global-hl-line-mode 1) ; 全局高亮当前视觉行
(column-number-mode 1) ; mode-line 不显示列号
(show-paren-mode 1) ; 开启括号匹配高亮

;; soft wraping
(setq-default truncate-lines nil ; 软换行, 拒绝强行截断
              word-wrap t ; 软换行在单词边界断开, 而不是窗口边缘
              word-wrap-by-category t ; 改善 CJK 单词软换行体验
              )

(require 'visual-wrap)
(setq visual-wrap-extra-indent 0) ; 原行换行不额外缩进字符
(global-visual-line-mode 1) ; 全局开启视觉行, 不使用逻辑行
(global-visual-wrap-prefix-mode 1) ; 让软换行后的续行继承原逻辑行的缩进

(setq ring-bell-function #'ignore
      use-short-answers t
      confirm-kill-emacs #'yes-or-no-p
      sentence-end-double-space nil)

(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 80)


(delete-selection-mode 1)
(electric-pair-mode 1)


(provide 'sov-core)
