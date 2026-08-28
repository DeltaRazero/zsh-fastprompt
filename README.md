# FastPrompt

FastPrompt is a fast, light, minimalistic, and tiny ZSH prompt framework designed for speed and simplicity.

---

*Why another framework? When you have to work on a Windows device with an overly aggressive antivirus that scans \*everything\* when a file is accessed or a subprocess is started, things like OMZSH or Starship (10MB binary lol) are simply too slow.*

## Usage

### Initialization

Before adding modules to your prompt, call `fastprompt_init` to reset variables and register the necessary precmd hooks.

```zsh
source ~/.config/zsh/fastprompt.zsh
fastprompt_init
```

### Prompt Modules

* **`fastprompt_add_raw [string] [flags]`**

  Appends a raw text string to the prompt. Supports all standard formatting flags.

  *Additional flags:*
  * `-dynamic` : Re-evaluates dynamic ZSH variables inside the string on every prompt update.

* **`fastprompt_add_user [flags]`**

  Appends current username (`%n`). Supports standard formatting flags.

* **`fastprompt_add_host [flags]`**

  Appends hostname (defaults to full hostname `%M`). Supports standard formatting flags.

  *Additional flags:*
  * `-short` : Displays short hostname (`%m`) instead.

* **`fastprompt_add_msystem [flags]`**

  Appends the MSYS2 `$MSYSTEM` environment variable value. Supports standard formatting flags.

* **`fastprompt_add_dir [flags]`**

  Appends the current working directory (`%~`). Supports standard formatting flags.

* **`fastprompt_add_git [flags]`**

  Appends fast, cached Git status information (branch, state, local/remote changes). Requires `git`.

  *Additional flags:*
  * `-force-recheck-delay <seconds>` : Delay in seconds before re-scanning directory path for Git repository roots (default: 360).

### Formatting Options

All prompt modules accept formatting flags derived from the core `_fastprompt_format` engine.

#### Available Flags

* **Text Styling:**
  * `-bold` : Renders text in bold.
  * `-underline` : Underlines text.
  * `-standout` : Applies standout mode.

* **Colors:**
  * `-fg <color>` : Sets foreground color (accepts ZSH color names/numbers or `normal^privileged` syntax).
  * `-bg <color>` : Sets background color (accepts ZSH color names/numbers or `normal^privileged` syntax).
  * `-fg-keep` : Prevents resetting foreground color at the end.
  * `-bg-keep` : Prevents resetting background color at the end.

* **Separators & Padding:**
  * `-prefix <str>` : Text printed before value (inherits text colors).
  * `-suffix <str>` : Text printed after value (inherits text colors).
  * `-padding <int[,int]>` : Adds equal spaces to both sides of the value, or separately to the left side and right side when values are split by a comma.
  * `-start-separator <str>` : String printed before the item using its background color as foreground.
  * `-end-separator <str>` : String printed after the item using its background color as foreground.

* **Behavior:**
  * `-sticky` : Disables trailing spaces after the item.
  * `-empty` : Allows printing empty values.

> [!INFO]
> For the \[string\] value that is eventually passed to `fastprompt_add_raw` and the color string values (e.g. `-fg`), you can use the `value1^value2` syntax (e.g., `-fg "69^197"` or `"user^root"`) to dynamically display the first value for standard users and the second value when running with elevated privileges (`#`).

## Examples

### Minimalist Line Prompt

![](./res/prompt_example_01.png)

```sh
source ~/.config/zsh/fastprompt.zsh

fastprompt_init
fastprompt_add_msystem -fg "62"
fastprompt_add_user    -fg "69^197" -sticky
fastprompt_add_raw ":" -fg "253"    -sticky
fastprompt_add_dir     -fg "147"
fastprompt_add_git     -fg "73" -prefix "%f[" -suffix "%f]" -force-recheck-delay 2
fastprompt_add_raw "❯" -bold
```

### Powerline-Style Block Prompt

![](./res/prompt_example_02.png)

```sh
source ~/.config/zsh/fastprompt.zsh

fastprompt_init
fastprompt_add_user     -fg "white" -bg "26"  -bg-keep -padding 1,0 -sticky -start-separator ""
fastprompt_add_raw  ":" -fg "white"           -bg-keep              -sticky -start-separator ""
fastprompt_add_host     -fg "white"           -bg-keep -padding 0,1 -sticky -start-separator "" -short
fastprompt_add_dir      -fg "white" -bg "23"  -bg-keep -padding 0,1 -sticky -start-separator "🭨"
fastprompt_add_git      -fg "white" -bg "172" -bg-keep -padding 0,1 -sticky -start-separator "🭨" -force-recheck-delay 2
fastprompt_add_raw -empty -start-separator "🭨" -bg 0
```
