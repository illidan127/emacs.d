Eat's name self-explanatory, it stands for "Emulate A Terminal".
Eat is a terminal emulator.  It can run most (if not all)
full-screen terminal programs, including Emacs.

It is pretty fast, more than three times faster than Term, despite
being implemented entirely in Emacs Lisp.  So fast that you can
comfortably run Emacs inside Eat, or even use your Emacs as a
terminal multiplexer.

It has many feature that other Emacs terminal emulator still don't
have, for example complete mouse support.

It flickers less than other Emacs terminal emulator, so you get
more performance and a smooth experience.

To start Eat, run M-x eat.  Eat has three keybinding modes:

  * "semi-char" mode: This is the default keybinding mode.  Most
    keys are bound to send the key to the terminal, except the
    following keys: `C-\', `C-c', `C-x', `C-g', `C-h', `C-M-c',
    `C-u', `M-x', `M-:', `M-!', `M-&' and some other keys (see the
    user option `eat-semi-char-non-bound-keys' for the complete
    list).  The following special keybinding are available:

      * `C-q': Send next key to the terminal.
      * `C-y': Like `yank', but send the text to the terminal.
      * `M-y': Like `yank-pop', but send the text to the terminal.
      * `C-c' `C-k': Kill process.
      * `C-c' `C-e': Switch to "emacs" keybinding mode.
      * `C-c' `M-d': Switch to "char" keybinding mode.

  * "emacs" mode: No special keybinding, except the following:

      * `C-c' `C-j': Switch to "semi-char" keybinding mode.
      * `C-c' `M-d': Switch to "char" keybinding mode.
      * `C-c' `C-k': Kill process.

  * "char" mode: All supported keys are bound to send the key to
    the terminal, except `C-M-m' or `M-RET', which is bound to
    switch to "semi-char" keybinding mode.

If you like Eshell, then there is a good news for you.  Eat
integrates with Eshell.  Eat has two global minor modes for Eshell:

  * `eat-eshell-visual-command-mode': Run visual commands with Eat
    instead of Term.

  * `eat-eshell-mode': Run Eat inside Eshell.  After enabling this,
    you can run full-screen terminal programs directly in Eshell.
    You have three keybinding modes here too, except that `C-c'
    `C-k' is not special (i.e. not bound by Eat) in "emacs" mode
    and "line" mode.
